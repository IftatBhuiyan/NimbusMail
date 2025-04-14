import Foundation
import Combine
import FirebaseAuth
import AuthenticationServices
import Firebase
import SwiftUI
import GoogleSignIn
import GoogleAPIClientForREST_Gmail

@MainActor
class UserViewModel: ObservableObject {
    // Published properties
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var addedAccounts: [EmailAccount] = []
    @Published var inboxEmails: [EmailDisplayData] = [] // Use new name
    @Published var isFetchingEmails = false // Loading state for email fetch
    
    // Auth service (keep private)
    private var authService: AuthenticationService?
    private var cancellables = Set<AnyCancellable>()
    
    // Default Initializer (for live app)
    init() {
        self.authService = AuthenticationService.shared // Assign here
        
        // Subscribe to authentication state changes
        authService?.$isUserAuthenticated
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        // Subscribe to current user changes
        authService?.$currentUser
            .sink { [weak self] user in
                self?.userEmail = user?.email
                self?.userName = user?.displayName
            }
            .store(in: &cancellables)
        
        // Check current auth state (avoid direct call if possible, rely on publisher)
        // If direct check is needed, ensure Firebase is configured or handle nil
        if FirebaseApp.app() != nil { // Basic check if Firebase is configured
             isAuthenticated = Auth.auth().currentUser != nil
             userEmail = Auth.auth().currentUser?.email
             userName = Auth.auth().currentUser?.displayName
        } else {
            print("Warning: Firebase not configured in UserViewModel init. State might be inaccurate.")
            isAuthenticated = false // Default state if Firebase isn't ready
        }
        
        loadAccounts() // Load accounts on init
        fetchAllInboxMessages() // Fetch emails on init
    }
    
    // Initializer for Previews & Testing
    init(isAuthenticated: Bool, userEmail: String?, userName: String?, addedAccounts: [EmailAccount] = [], inboxEmails: [EmailDisplayData] = []) { // Use new name
        self.isAuthenticated = isAuthenticated
        self.userEmail = userEmail
        self.userName = userName
        self.addedAccounts = addedAccounts // Initialize accounts for preview
        self.inboxEmails = inboxEmails // Initialize for preview
    }
    
    // MARK: - Account Management
    
    // Function to add a new account (placeholder for now)
    // In reality, this would likely be called after successful OAuth AND Keychain save
    func addAccount(email: String, provider: String, refreshToken: String) {
        // 1. Save refresh token using KeychainService (already done in AddAccountProviderView)
        // let saveSuccessful = KeychainService.save(token: refreshToken, account: email)
        // guard saveSuccessful else { /* handle error */ return }
        
        // 2. Check if account already exists
        if !addedAccounts.contains(where: { $0.emailAddress == email }) {
            let newAccount = EmailAccount(emailAddress: email, provider: provider)
            addedAccounts.append(newAccount)
            // TODO: Persist the addedAccounts list (e.g., UserDefaults with email addresses, Keychain for secure mapping)
            // TODO: Optionally trigger initial folder/email fetch for the new account
            print("Account added: \(email)")
            // Fetch emails for the newly added account
            fetchInboxMessages(for: newAccount)
        } else {
            print("Account already exists: \(email)")
            // Optionally update existing account info/tokens if needed
        }
    }
    
    func removeAccount(account: EmailAccount) {
        // 1. Delete refresh token from Keychain
        let deleteSuccessful = KeychainService.deleteToken(account: account.emailAddress)
        if !deleteSuccessful {
             print("Warning: Failed to delete token from keychain for \(account.emailAddress), but removing from list anyway.")
        }
        
        // 2. Remove from the list
        addedAccounts.removeAll { $0.id == account.id }
        // TODO: Update persisted account list
        print("Account removed: \(account.emailAddress)")
    }
    
    // Function to load accounts (placeholder)
    // TODO: Implement loading from persisted storage (e.g., fetch list from UserDefaults/Keychain)
    private func loadAccounts() {
        // Example: Load a list of email addresses from UserDefaults
        // For each email, try loading its token from Keychain
        // If token exists, create an EmailAccount and add to addedAccounts
        print("Placeholder: loadAccounts() called. Implement persistence.")
        // self.addedAccounts = previouslySavedAccounts
    }
    
    // MARK: - Email Fetching
    
    // Fetches for all accounts (simple aggregation for now)
    func fetchAllInboxMessages() {
        guard !isFetchingEmails else { return }
        print("Starting fetch for all account inboxes...")
        isFetchingEmails = true
        inboxEmails = [] // Clear existing emails before fetching
        
        let dispatchGroup = DispatchGroup()
        var combinedMessages: [GTLRGmail_Message] = [] // Raw messages with IDs
        var fetchErrors: [Error] = []

        for account in addedAccounts {
            dispatchGroup.enter()
            // Fetch only enough IDs for initial display
            GmailAPIService.shared.fetchInboxMessages(for: account, maxTotalMessages: 20) { result in
                switch result {
                case .success(let messages):
                    // Combine messages (or handle per account)
                    combinedMessages.append(contentsOf: messages)
                    print("Fetched \(messages.count) message IDs for \(account.emailAddress)")
                case .failure(let error):
                    print("Failed to fetch messages for \(account.emailAddress): \(error.localizedDescription)")
                    fetchErrors.append(error)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isFetchingEmails = false
            print("Finished fetching all message IDs. Total IDs: \(combinedMessages.count)")
            if !fetchErrors.isEmpty {
                // Handle errors appropriately (e.g., show combined error message)
                self.errorMessage = "Error fetching emails for some accounts."
            }
            
            // Start fetching details once all IDs are collected
             self.fetchDetailsForMessages(combinedMessages)
        }
    }
    
    // Helper function to fetch details for a list of message IDs using TaskGroup
    private func fetchDetailsForMessages(_ messageInfos: [GTLRGmail_Message]) {
        guard !messageInfos.isEmpty else {
            print("No message IDs to fetch details for.")
            self.isFetchingEmails = false
            self.inboxEmails = []
            return
        }

        let detailFetchLimit = 10
        let infosToFetch = Array(messageInfos.prefix(detailFetchLimit))

        print("Starting TaskGroup to fetch details for \(infosToFetch.count) messages...")
        self.isFetchingEmails = true
        
        // Capture addedAccounts on the MainActor before starting the background task
        let currentAddedAccounts = self.addedAccounts

        // Create a Task to manage the TaskGroup off the main thread initially
        Task {
            var detailedEmails: [EmailDisplayData] = [] // Use new name
            var detailFetchErrors: [Error] = []
            
            // Use withTaskGroup for structured concurrency
            await withTaskGroup(of: Result<EmailDisplayData, Error>.self) { group in // Use new name
                for messageInfo in infosToFetch {
                    guard let messageId = messageInfo.identifier else { continue }

                    // Add a task to the group for each message detail fetch
                    group.addTask { 
                        do {
                            print("[TaskGroup Child \(messageId)]: Fetching details...")
                            let detailedMessage = try await self.fetchMessageDetailsAsync(for: currentAddedAccounts.first!, messageId: messageId)
                            print("[TaskGroup Child \(messageId)]: Got details, mapping...")
                            // Mapping needs to be isolated if EmailDisplayData is not Sendable, 
                            // but since it's simple struct, it likely is. 
                            // Run mapping off main actor initially.
                            // Add await as mapGTLRMessageToEmailDisplayData is isolated to MainActor
                            let emailData = await self.mapGTLRMessageToEmailDisplayData(detailedMessage) // Use new name
                            print("[TaskGroup Child \(messageId)]: Mapped successfully.")
                            return .success(emailData)
                        } catch {
                             print("[TaskGroup Child \(messageId)]: ERROR fetching details: \(error.localizedDescription)")
                            return .failure(error)
                        }
                    }
                }

                // Collect results as they complete
                for await result in group {
                    switch result {
                    case .success(let email):
                        detailedEmails.append(email)
                    case .failure(let error):
                        detailFetchErrors.append(error)
                    }
                }
            }
            
            // Update UI on the main thread after group finishes
            await MainActor.run {
                print("TaskGroup finished. Successfully fetched: \(detailedEmails.count), Errors: \(detailFetchErrors.count)")
                self.isFetchingEmails = false
                self.inboxEmails = detailedEmails.sorted { $0.date > $1.date }
                
                if !detailFetchErrors.isEmpty {
                    self.errorMessage = "Error fetching details for some emails."
                }
            }
        }
    }

    // Async wrapper for fetchMessageDetails (needed for Task usage)
    private func fetchMessageDetailsAsync(for account: EmailAccount, messageId: String) async throws -> GTLRGmail_Message {
        try await withCheckedThrowingContinuation { continuation in
            GmailAPIService.shared.fetchMessageDetails(for: account, messageId: messageId) { result in
                switch result {
                case .success(let message):
                    continuation.resume(returning: message)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Mapping function (adjust based on EmailDisplayData properties)
    private func mapGTLRMessageToEmailDisplayData(_ gtlrMessage: GTLRGmail_Message) -> EmailDisplayData { // Renamed function
        // Extract headers - Requires careful parsing
        var subject = "No Subject"
        var from = "Unknown Sender"
        var date = Date() // Default date
        let snippet = gtlrMessage.snippet ?? ""
        // Get the actual Gmail message ID
        let gmailId = gtlrMessage.identifier ?? "invalid-id-\(UUID().uuidString)"

        if let payload = gtlrMessage.payload, let headers = payload.headers {
            for header in headers {
                guard let name = header.name, let value = header.value else { continue }
                switch name.uppercased() {
                case "SUBJECT":
                    subject = value
                case "FROM":
                    // Basic parsing, might need refinement for "Name <email>" format
                    from = value.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? value
                case "DATE":
                    // Gmail dates are RFC 2822 - Use DateFormatter
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Important!
                    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z" // Common format
                    if let parsedDate = dateFormatter.date(from: value) {
                        date = parsedDate
                    } else {
                         // Try alternative format if first fails
                         dateFormatter.dateFormat = "dd MMM yyyy HH:mm:ss Z"
                         if let parsedDateAlt = dateFormatter.date(from: value) {
                             date = parsedDateAlt
                         } else {
                              print("Warning: Could not parse date string: \(value)")
                         }
                    }
                default:
                    break
                }
            }
        }

        return EmailDisplayData( // Use new name
            // Pass the actual Gmail ID
            gmailMessageId: gmailId, 
            sender: from,
            senderEmail: nil, // Not typically in metadata headers, fetch if needed
            recipient: nil, // Requires parsing 'To' header, omit for now
            subject: subject,
            snippet: snippet, // Use the snippet from the API
            body: "", // Body not fetched with metadata
            date: date,
            isRead: !(gtlrMessage.labelIds?.contains("UNREAD") ?? false), // Check for UNREAD label
            previousMessages: nil // Not fetched with metadata
        )
    }

    // Fetches for a single account (called when adding account)
    private func fetchInboxMessages(for account: EmailAccount) {
         // Fetch only enough IDs for initial display
         GmailAPIService.shared.fetchInboxMessages(for: account, maxTotalMessages: 20) { [weak self] result in 
             guard let self = self else { return }
             // Similar to above, but likely wouldn't immediately update the main inboxEmails
             // Might update a per-account cache or trigger a refresh of fetchAllInboxMessages
             switch result {
             case .success(let messageInfos): // Renamed for clarity
                 print("Fetched \(messageInfos.count) initial message IDs for newly added account \(account.emailAddress)")
                 // Trigger detail fetch for these IDs
                  self.fetchDetailsForMessages(messageInfos) 
             case .failure(let error):
                 // Corrected print statement
                 print("Failed fetch for new account \(account.emailAddress): \(error.localizedDescription)")
                 // Optionally set error message
                 self.isFetchingEmails = false // Make sure loading stops on error
             }
         }
    }
    
    // MARK: - Authentication Methods
    
    // Modify methods to safely unwrap authService or handle nil
    func signIn(email: String, password: String) async {
        guard let authService = authService else { 
            handleError(.unknown(message: "AuthService not initialized"))
            return
        }
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signInWithEmail(email: email, password: password)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    func signUp(email: String, password: String) async {
        guard let authService = authService else { 
            handleError(.unknown(message: "AuthService not initialized"))
            return
        }
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUpWithEmail(email: email, password: password)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    func signOut() {
        guard let authService = authService else { 
            handleError(.unknown(message: "AuthService not initialized"))
            return
        }
        errorMessage = nil
        
        do {
            try authService.signOut()
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    func resetPassword(email: String) async {
        guard let authService = authService else { 
            handleError(.unknown(message: "AuthService not initialized"))
            return
        }
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(for: email)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    func signInWithApple(authorization: ASAuthorization) async {
        guard let authService = authService else { 
            handleError(.unknown(message: "AuthService not initialized"))
            return
        }
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signInWithApple(authorization: authorization)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    // MARK: - Skip Authentication
    
    func handleSkipAuthentication() async {
        // Reset any errors and loading state
        errorMessage = nil
        isLoading = false
        
        // Set the authentication state to allow access
        self.isAuthenticated = true
        
        // You can set default user information for guest users if needed
        self.userEmail = "guest@example.com"
        self.userName = "Guest User"
    }
    
    // Handle all authentication errors
    private func handleError(_ error: AuthError) {
        isLoading = false
        
        switch error {
        case .signInError(let message),
             .signUpError(let message),
             .signOutError(let message),
             .unknown(let message):
            errorMessage = message
        case .userNotFound:
            errorMessage = "User not found. Please check your email or sign up."
        case .invalidCredentials:
            errorMessage = "Invalid email or password. Please try again."
        }
    }

    // MARK: - Fetch Full Email Body

    func fetchFullEmailBody(for messageId: String) async -> String? {
        print("ViewModel: Attempting to fetch full body for message \(messageId)")
        guard let primaryAccount = addedAccounts.first else {
            print("ViewModel Error: No primary account found to fetch body.")
            errorMessage = "No account configured."
            return nil
        }

        do {
            // Create an async wrapper similar to fetchMessageDetailsAsync if needed,
            // or directly use continuation if the service method isn't async yet.
            let fullMessage = try await fetchFullMessageAsync(for: primaryAccount, messageId: messageId)
            // Use the new helper that prioritizes HTML
            let body = GmailAPIService.extractBestBody(from: fullMessage) 
            print("ViewModel: Successfully extracted body for \(messageId). Length: \(body?.count ?? 0)")
            return body
        } catch {
            print("ViewModel Error: Failed to fetch full message for \(messageId): \(error.localizedDescription)")
            errorMessage = "Failed to load email content."
            return nil
        }
    }

    // Async wrapper for fetchFullMessage
    private func fetchFullMessageAsync(for account: EmailAccount, messageId: String) async throws -> GTLRGmail_Message {
        try await withCheckedThrowingContinuation { continuation in
            GmailAPIService.shared.fetchFullMessage(for: account, messageId: messageId) { result in
                switch result {
                case .success(let message):
                    continuation.resume(returning: message)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
} 