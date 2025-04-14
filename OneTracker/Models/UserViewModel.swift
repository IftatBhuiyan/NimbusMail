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
    
    // Computed property for suggested contacts
    var suggestedContacts: [String] {
        var contacts = Set<String>()
        print("[ViewModel Debug] inboxEmails count for suggestions: \(inboxEmails.count)") // Log count
        
        // Helper function to add cleaned emails to the set
        func addEmails(from string: String?) {
            guard let string = string, !string.isEmpty else { return }
            // Split by comma
            let potentialEmails = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            for emailString in potentialEmails {
                 // Basic validation and cleaning (remove potential name/brackets)
                 let components = emailString.components(separatedBy: "<")
                 var potentialEmail = emailString // Default to the whole string
                 if components.count > 1, let emailPart = components.last?.trimmingCharacters(in: [">", " "]) {
                     potentialEmail = emailPart
                 } 
                 // Final check if it looks like an email and add lowercase
                 if potentialEmail.contains("@") {
                     contacts.insert(potentialEmail.lowercased())
                 }
            }
        }

        for email in inboxEmails {
            addEmails(from: email.senderEmail)
            addEmails(from: email.recipient)
            // TODO: Consider parsing CC/BCC headers if available in full fetch
        }
        let sortedContacts = Array(contacts).sorted()
        print("[ViewModel Debug] suggestedContacts computed: \(sortedContacts)") // Log result
        return sortedContacts
    }
    
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
    
    // Fetches emails for all added accounts, replacing the old logic
    func fetchAllInboxMessages() { // Keep name for now, but fetches threads
        guard !isFetchingEmails else { return }
        print("Starting fetch for all account inboxes (fetching threads)...")
        isFetchingEmails = true
        inboxEmails = [] // Clear existing emails before fetching
        errorMessage = nil
        
        // Assume primary account for now, adjust if multi-account support needed here
        guard let primaryAccount = addedAccounts.first else {
            print("No primary account configured.")
            errorMessage = "No account configured to fetch emails."
            isFetchingEmails = false
            return
        }

        // Call the new thread fetching service method
        GmailAPIService.shared.fetchInboxThreads(for: primaryAccount, maxTotalThreads: 50) { [weak self] result in
            guard let self = self else { return }
            
            Task { // Perform mapping and state update on MainActor
                await MainActor.run {
                    self.isFetchingEmails = false
                    switch result {
                    case .success(let threads):
                        print("Successfully fetched \(threads.count) threads. Processing...")
                        self.inboxEmails = self.mapAndStructureThreads(threads)
                        print("Finished processing threads. Inbox count: \(self.inboxEmails.count)")
                        // --- Inject mock threaded email (keeping for reference) ---
                        self.injectMockThread() 
                        // --- End mock injection ---
                        
                    case .failure(let error):
                        print("Failed to fetch threads: \(error.localizedDescription)")
                        self.errorMessage = "Failed to load emails: \(error.localizedDescription)"
                        // Consider keeping mock thread even on failure for UI testing
                        self.injectMockThread() 
                    }
                }
            }
        }
    }
    
    // --- New Thread Processing Logic ---
    private func mapAndStructureThreads(_ threads: [GTLRGmail_Thread]) -> [EmailDisplayData] {
        var structuredEmails: [EmailDisplayData] = []

        for thread in threads {
            guard let messages = thread.messages, !messages.isEmpty else { continue }

            // Map all messages in the thread using the existing mapper
            var mappedMessages = messages.compactMap { self.mapGTLRMessageToEmailDisplayData($0) }
            
            // Sort messages by date (oldest first for building history)
            mappedMessages.sort { $0.date < $1.date }
            
            // Build the nested structure
            var latestMessage: EmailDisplayData? = nil
            var history: [EmailDisplayData] = []
            
            for i in stride(from: mappedMessages.count - 1, through: 0, by: -1) {
                var currentMessage = mappedMessages[i]
                if latestMessage == nil { // This is the most recent message
                    // Set the history built so far
                    currentMessage.previousMessages = history.isEmpty ? nil : history
                    latestMessage = currentMessage
                } else {
                    // Add the *next* message (which is chronologically later) to the history stack
                    history.insert(latestMessage!, at: 0) // Prepend to keep order
                    // Update current message's history pointer
                    currentMessage.previousMessages = history.isEmpty ? nil : history
                    latestMessage = currentMessage // Move latest pointer back
                }
            }

            // Add the latest message (which now contains the history) to the final list
            if let rootMessageToShow = latestMessage {
                structuredEmails.append(rootMessageToShow)
            }
        }
        
        // Sort the final list of threads by the date of their latest message (newest first)
        structuredEmails.sort { $0.date > $1.date }
        
        return structuredEmails
    }
    
    // Helper to inject mock thread (extracted for reuse)
    private func injectMockThread() {
        let mockOriginal = EmailDisplayData(
            gmailMessageId: "originalMsgId",
            threadId: "mockThread1",
            messageIdHeader: "<mock-original@example.com>",
            referencesHeader: nil,
            sender: "Alice (Preview)",
            senderEmail: "alice.preview@example.com",
            recipient: "Bob (Preview)",
            subject: "Project Update",
            snippet: "Initial project update...",
            body: "Hi Bob,\n\nHere's the initial update on the project.\n\nBest,\nAlice",
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            isRead: true,
            previousMessages: nil
        )
        let mockReply1 = EmailDisplayData(
            gmailMessageId: "reply1MsgId",
            threadId: "mockThread1",
            messageIdHeader: "<mock-reply1@example.com>",
            referencesHeader: "<mock-original@example.com>",
            sender: "Bob (Preview)",
            senderEmail: "bob.preview@example.com",
            recipient: "Alice (Preview)",
            subject: "Re: Project Update",
            snippet: "Thanks for the update, Alice...",
            body: "Hi Alice,\n\nThanks for the update! A couple of questions...\n\nBest,\nBob",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            isRead: true,
            previousMessages: [mockOriginal]
        )
        let mockReply2 = EmailDisplayData(
            gmailMessageId: "reply2MsgId",
            threadId: "mockThread1",
            messageIdHeader: "<mock-reply2@example.com>",
            referencesHeader: "<mock-original@example.com> <mock-reply1@example.com>",
            sender: "Alice (Preview)",
            senderEmail: "alice.preview@example.com",
            recipient: "Bob (Preview)",
            subject: "Re: Project Update",
            snippet: "Here's some clarification...",
            body: "Hi Bob,\n\nHere are answers to your questions...\n\nBest,\nAlice",
            date: Date(),
            isRead: false,
            previousMessages: [mockReply1]
        )
        
        // Remove any previous mock thread if present
        inboxEmails.removeAll { $0.threadId == "mockThread1" }
        // Insert mock thread at the top
        inboxEmails.insert(mockReply2, at: 0)
    }
    
    // --- End Thread Processing Logic ---
    
    // (Remove or comment out fetchDetailsForMessages and fetchMessageDetailsAsync as they are replaced by the thread logic)
    /*
    // Helper function to fetch details for a list of message IDs using TaskGroup
    private func fetchDetailsForMessages(_ messageInfos: [GTLRGmail_Message]) {
        // ... existing implementation ...
    }
    
    // Async wrapper for fetchMessageDetails (needed for TaskGroup)
    private func fetchMessageDetailsAsync(for account: EmailAccount, messageId: String) async throws -> GTLRGmail_Message {
        // ... existing implementation ...
    }
    */

    // Mapping function (adjust based on EmailDisplayData properties)
    private func mapGTLRMessageToEmailDisplayData(_ gtlrMessage: GTLRGmail_Message) -> EmailDisplayData { // Renamed function
        // Extract headers - Requires careful parsing
        var subject = "No Subject"
        var from = "Unknown Sender"
        var senderEmail: String? = nil // Added for clarity
        var recipient: String? = nil // Variable to store the recipient
        var date = Date() // Default date, will be overwritten
        let snippet = gtlrMessage.snippet ?? ""
        // Get the actual Gmail message ID
        let gmailId = gtlrMessage.identifier ?? "invalid-id-\(UUID().uuidString)"
        // Get the Thread ID
        let threadId = gtlrMessage.threadId
        // Extract Message-ID and References headers
        var messageIdHeader: String? = nil
        var referencesHeader: String? = nil

        // --- Prioritize internalDate for reliable sorting --- 
        if let internalDateMillis = gtlrMessage.internalDate?.int64Value {
             // internalDate is milliseconds since epoch, convert to Date
             date = Date(timeIntervalSince1970: TimeInterval(internalDateMillis) / 1000.0)
        } else {
             // --- Fallback: Attempt to parse Date header (less reliable) --- 
             var headerDate: Date? = nil
             if let payload = gtlrMessage.payload, let headers = payload.headers {
                for header in headers {
                    guard let name = header.name, let value = header.value else { continue }
                    if name.uppercased() == "DATE" {
                         headerDate = parseDateHeader(value)
                         break // Stop after finding the Date header
                    }
                }
            }
             // If header parsing succeeded, use it; otherwise, keep the default Date()
             if let parsedHeaderDate = headerDate {
                 date = parsedHeaderDate
                 print("Used parsed Date header for \(gmailId)")
             } else {
                 print("Warning: Could not get internalDate or parse Date header for \(gmailId). Using current date.")
             }
             // --- End Fallback ---
        }
        // --- End Date Logic ---

        // --- Parse other headers (Subject, From, To) --- 
        if let payload = gtlrMessage.payload, let headers = payload.headers {
            for header in headers {
                guard let name = header.name, let value = header.value else { continue }
                switch name.uppercased() {
                case "SUBJECT":
                    subject = value
                case "FROM":
                    // Basic parsing for sender name and email
                    let components = value.components(separatedBy: "<")
                    from = components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? value
                    if components.count > 1, let emailPart = components.last?.trimmingCharacters(in: [">", " "]) {
                        senderEmail = emailPart
                    } else if value.contains("@") { // Fallback if no brackets
                        senderEmail = value
                    }
                case "TO": // Add case to parse 'To' header
                    // Parse recipient email address, similar to FROM
                    let components = value.components(separatedBy: "<")
                    // If name and email format, extract email
                    if components.count > 1, let emailPart = components.last?.trimmingCharacters(in: [">", " "]) {
                        recipient = emailPart
                    } 
                    // If only email or parsing failed, use the whole value if it looks like an email
                    else if value.contains("@") { 
                        recipient = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    } 
                    // Consider logging or handling cases where 'To' doesn't contain a valid address
                    else {
                         print("Warning: Could not parse recipient email from To header: \(value)")
                         recipient = nil // Or keep original value if preferred, but nil is safer for suggestions
                    }
                case "MESSAGE-ID": // Extract Message-ID
                    messageIdHeader = value
                case "REFERENCES": // Extract References
                    referencesHeader = value
                // We already handled DATE above
                default:
                    break
                }
            }
        }
        // --- End Header Parsing ---

        return EmailDisplayData( // Use new name
            // Pass the actual Gmail ID
            gmailMessageId: gmailId, 
            threadId: threadId, // Add threadId here
            messageIdHeader: messageIdHeader, // Add Message-ID header
            referencesHeader: referencesHeader, // Add References header
            sender: from,
            senderEmail: senderEmail, // Use the parsed sender email
            recipient: recipient, // Use the parsed recipient value
            subject: subject,
            snippet: snippet, // Use the snippet from the API
            body: "", // Body not fetched with metadata
            date: date, // Use the date determined above (prioritizing internalDate)
            isRead: !(gtlrMessage.labelIds?.contains("UNREAD") ?? false), // Check for UNREAD label
            previousMessages: nil // Not fetched with metadata
        )
    }

    // Helper function to parse common date formats found in email headers
    private func parseDateHeader(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Crucial for RFC dates

        // List of common date formats to try
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",           // RFC 822 / 2822
            "dd MMM yyyy HH:mm:ss Z",              // Variation without day name
            "EEE, dd MMM yyyy HH:mm Z",            // Variation without seconds
            "dd MMM yyyy HH:mm Z",                 // Variation without day name/seconds
            "EEE, d MMM yyyy HH:mm:ss Z",          // Single digit day
            "d MMM yyyy HH:mm:ss Z",               // Single digit day, no day name
            "EEE, dd MMM yyyy HH:mm:ss zzz",       // Format with timezone name (e.g., GMT)
            "dd MMM yyyy HH:mm:ss zzz",          // Format with timezone name, no day name
            "yyyy-MM-dd'T'HH:mm:ssZ",              // ISO 8601
            "yyyy-MM-dd HH:mm:ss Z"                // Another common format
        ]

        // Clean the date string: remove extra spaces, timezone names in parens
        var cleanedString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove timezone abbreviations in parentheses (e.g., " (CDT)", " (GMT)")
        if let range = cleanedString.range(of: "\\s*\\([^)]+\\)$", options: .regularExpression) {
            cleanedString.removeSubrange(range)
            cleanedString = cleanedString.trimmingCharacters(in: .whitespacesAndNewlines) // Trim again after removal
        }

        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: cleanedString) {
                return date
            }
        }

        // If none of the standard formats worked, log a warning
        print("Warning: Exhausted common formats, could not parse date header string: \(dateString)")
        return nil
    }

    // Fetches for a single account (called when adding account)
    private func fetchInboxMessages(for account: EmailAccount) {
         // Trigger a full refresh of the inbox, which now fetches threads
         print("Triggering full inbox refresh after adding account: \(account.emailAddress)")
         self.fetchAllInboxMessages()
         /* // Remove old logic
         // Fetch only enough IDs for initial display
         GmailAPIService.shared.fetchInboxMessages(for: account, maxTotalMessages: 50) { [weak self] result in 
             guard let self = self else { return }
             // Similar to above, but likely wouldn't immediately update the main inboxEmails
             // Might update a per-account cache or trigger a refresh of fetchAllInboxMessages
             switch result {
             case .success(let messageInfos): // Renamed for clarity
                 print("Fetched \(messageInfos.count) initial message IDs for newly added account \(account.emailAddress)")
                 // Trigger detail fetch for these IDs
                  // self.fetchDetailsForMessages(messageInfos) // This function is now commented out
             case .failure(let error):
                 // Corrected print statement
                 print("Failed fetch for new account \(account.emailAddress): \(error.localizedDescription)")
                 // Optionally set error message
                 self.isFetchingEmails = false // Make sure loading stops on error
             }
         }
         */
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

    // Fetches and parses the full email body into reply and quote parts.
    func fetchFullEmailBodyParts(for messageId: String) async -> (reply: String?, quote: String?) {
        print("ViewModel: Attempting to fetch and parse full body parts for message \(messageId)")
        
        // --- Handle mock emails locally (return tuple) ---
        let mockIds = ["reply2MsgId", "reply1MsgId", "originalMsgId"]
        if mockIds.contains(messageId) {
            if let mockEmail = inboxEmails.first(where: { $0.gmailMessageId == messageId }) {
                print("ViewModel: Parsing local body for mock email \(messageId)")
                // Use the parsing logic even for mocks to simulate real behavior
                return GmailAPIService.parseBodyStringForReplyAndQuote(mockEmail.body)
            } else {
                print("ViewModel Error: Mock email not found in inboxEmails for id \(messageId)")
                return (nil, nil)
            }
        }
        // --- End mock handling ---
        
        guard let primaryAccount = addedAccounts.first else {
            print("ViewModel Error: No primary account found to fetch body.")
            errorMessage = "No account configured."
            return (nil, nil)
        }

        do {
            let fullMessage = try await fetchFullMessageAsync(for: primaryAccount, messageId: messageId)
            
            // Use the new parsing function from the API service
            let bodyParts = GmailAPIService.extractBestBodyParts(from: fullMessage) 
            print("ViewModel: Successfully extracted body parts for \(messageId). Reply length: \(bodyParts.reply?.count ?? 0), Quote length: \(bodyParts.quote?.count ?? 0)")
            return bodyParts
        } catch {
            print("ViewModel Error: Failed to fetch full message for \(messageId): \(error.localizedDescription)")
            errorMessage = "Failed to load email content."
            return (nil, nil)
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

    // MARK: - Send Email
    
    func sendEmail(to: String, cc: String?, bcc: String?, subject: String, bodyText: String, quotedText: String?, fromAddress: String, originalEmail: EmailDisplayData? = nil) async throws {
        isLoading = true // Indicate sending activity
        errorMessage = nil

        // Find the account to send from
        guard let account = addedAccounts.first(where: { $0.emailAddress == fromAddress }) else {
            let errorMsg = "Could not find sending account: \(fromAddress)"
            errorMessage = errorMsg
            isLoading = false
            throw NSError(domain: "UserViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        // Prepare plain text body
        var fullBody = bodyText
        if let quote = quotedText {
            // Strip HTML from quote for plain text sending
            let tagStrippingRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive)
            let range = NSRange(quote.startIndex..<quote.endIndex, in: quote)
            let plainQuote = tagStrippingRegex?.stringByReplacingMatches(in: quote, options: [], range: range, withTemplate: "") ?? quote
            // Basic decoding for plain text version
            let decodedPlainQuote = plainQuote
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")

            fullBody += "\n\n\(decodedPlainQuote)" // Append cleaned quote
        }

        // Call the service, passing the reply context
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            GmailAPIService.shared.sendEmail(for: account, to: to, cc: cc, bcc: bcc, subject: subject, body: fullBody, originalEmail: originalEmail) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // If successful, update state
        // Note: error is automatically thrown by continuation if failure occurs
        isLoading = false
        print("ViewModel: Email send reported as successful.")
        // Optionally: Refresh inbox? Trigger confirmation message?
    }
} 