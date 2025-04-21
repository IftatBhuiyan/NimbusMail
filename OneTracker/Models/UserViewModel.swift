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
    @Published var emailsByAccount: [String: [EmailDisplayData]] = [:]
    @Published var isFetchingEmails = false // Loading state for email fetch
    @Published var selectedAccountFilter: String? = nil // nil means All Inboxes
    @Published var labelsByAccount: [String: [GTLRGmail_Label]] = [:] // To store labels per account
    @Published var isFetchingLabels: [String: Bool] = [:] // Loading state per account for labels
    @Published var selectedLabelFilter: String? = nil // ID of the selected label/folder
    @Published var nextPageTokens: [String: String?] = [:] // Store next page token per account filter key
    @Published var isFetchingMoreEmails: Bool = false // Loading state for pagination
    
    // --- State for Side Menu --- 
    @Published var expandedAccountIDs: Set<UUID> = [] // Persists expanded state
    
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
    
    // Computed property to flatten emails for display (can be filtered later)
    var inboxEmails: [EmailDisplayData] {
        let filteredByAccount: [EmailDisplayData]
        if let selectedAccount = selectedAccountFilter {
            // Filter by selected account
            filteredByAccount = emailsByAccount[selectedAccount] ?? []
        } else {
            // Show all accounts (flattened)
            filteredByAccount = emailsByAccount.values.flatMap { $0 }
        }

        // Further filter by selected label if one is chosen
        let filteredByLabel: [EmailDisplayData]
        if let selectedLabel = selectedLabelFilter {
            filteredByLabel = filteredByAccount.filter { email in
                // Check if the email's labelIds array contains the selected label ID
                email.labelIds?.contains(selectedLabel) ?? false
            }
        } else {
            // If no label is selected, show all emails for the selected account(s)
            // We might want a default filter here (e.g., INBOX) if selectedAccountFilter is set
            // but selectedLabelFilter is nil. For now, show all.
            filteredByLabel = filteredByAccount
        }
        
        // Sort the final list
        return filteredByLabel.sorted { $0.date > $1.date }
    }
    
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
    init(isAuthenticated: Bool, userEmail: String?, userName: String?, addedAccounts: [EmailAccount] = [], emailsByAccount: [String: [EmailDisplayData]] = [:]) { // Update parameter
        self.isAuthenticated = isAuthenticated
        self.userEmail = userEmail
        self.userName = userName
        self.addedAccounts = addedAccounts // Initialize accounts for preview
        self.emailsByAccount = emailsByAccount // Initialize for preview
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
            saveAccounts() // Save after adding
            print("Account added: \(email)")
            // Fetch emails and labels for the newly added account
            fetchInboxMessages(for: newAccount)
            fetchLabels(for: newAccount)
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
        saveAccounts() // Save after removing
    }
    
    // Function to load accounts (placeholder)
    // TODO: Implement loading from persisted storage (e.g., fetch list from UserDefaults/Keychain)
    private func loadAccounts() {
        let key = userDefaultsKeyForAccounts
        guard key != "addedAccounts_loggedOut" else {
            print("Skipping loadAccounts: User is logged out.")
            self.addedAccounts = [] // Ensure accounts are cleared if logged out
            return
        }

        print("Attempting to load accounts from UserDefaults for key: \(key)")
        guard let data = UserDefaults.standard.data(forKey: key) else {
            print("No saved accounts data found in UserDefaults for key \(key).")
            self.addedAccounts = [] // Start with empty list if no data
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let loadedAccounts = try decoder.decode([EmailAccount].self, from: data)
            self.addedAccounts = loadedAccounts
            print("Successfully loaded \(loadedAccounts.count) accounts from UserDefaults.")
            
            // After loading, fetch labels for each account
            for account in loadedAccounts {
                fetchLabels(for: account)
                // Note: fetchInboxMessages(for:) is likely called by fetchAllInboxMessages in init,
                // so we might not need to call it explicitly here.
            }
        } catch {
            print("Error loading accounts from UserDefaults: \(error.localizedDescription). Resetting to empty.")
            self.addedAccounts = [] // Reset if decoding fails
        }
    }
    
    // MARK: - Account Persistence
    
    private var userDefaultsKeyForAccounts: String {
        // Create a unique key per logged-in Firebase user
        // Fallback to a generic key if no user is logged in (though less ideal)
        if let firebaseUserId = Auth.auth().currentUser?.uid {
            return "addedAccounts_\(firebaseUserId)"
        } else {
            // Handle the case where Firebase user is not available (e.g., during sign-out)
            // Maybe return a key that won't be saved, or a default? 
            // For now, let's return a key that indicates no user, preventing accidental saves.
            return "addedAccounts_loggedOut"
        }
    }

    private func saveAccounts() {
        // Ensure we have a valid key (i.e., user is logged in)
        let key = userDefaultsKeyForAccounts
        guard key != "addedAccounts_loggedOut" else {
            print("Skipping saveAccounts: User is logged out.")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(addedAccounts)
            UserDefaults.standard.set(data, forKey: key)
            print("Successfully saved \(addedAccounts.count) accounts to UserDefaults for key \(key).")
        } catch {
            print("Error saving accounts to UserDefaults: \(error.localizedDescription)")
            // Optionally update errorMessage
        }
    }
    
    // MARK: - Label Fetching

    func fetchLabels(for account: EmailAccount) {
        let accountEmail = account.emailAddress
        // Avoid redundant fetches if already loading or labels exist
        guard isFetchingLabels[accountEmail] != true, labelsByAccount[accountEmail] == nil else {
             print("Labels already fetched or currently fetching for \(accountEmail)")
             return
        }
        
        print("Fetching labels for \(accountEmail)")
        isFetchingLabels[accountEmail] = true
        
        // Call the service
        GmailAPIService.shared.fetchLabels(for: account) { [weak self] result in
            // Update state on main thread
            Task {
                await MainActor.run {
                    guard let self = self else { return }
                    self.isFetchingLabels[accountEmail] = false // Mark loading as complete
                    switch result {
                    case .success(let labels):
                        self.labelsByAccount[accountEmail] = labels
                        print("Successfully stored \(labels.count) labels for \(accountEmail).")
                        // --- Add Logging --- 
                        print("Fetched Label IDs/Names for \(accountEmail):")
                        labels.forEach { print("  ID: \($0.identifier ?? "N/A"), Name: \($0.name ?? "N/A"), Type: \($0.type ?? "N/A")") }
                        // --- End Logging ---
                        // TODO: Potentially trigger UI update if SideMenuView depends on this directly
                    case .failure(let error):
                        // Handle error (e.g., update errorMessage)
                        print("Failed to fetch labels for \(accountEmail): \(error.localizedDescription)")
                        self.errorMessage = "Failed to load folders for \(accountEmail)."
                    }
                }
            }
        }
    }

    // MARK: - Email Fetching
    
    // Fetches emails for all added accounts, replacing the old logic
    func fetchAllInboxMessages() { // Keep name for now, but fetches threads
        guard !isFetchingEmails else { return }
        guard !addedAccounts.isEmpty else {
            print("No accounts configured. Skipping fetch.")
            // Clear the dictionary if no accounts exist
            Task { await MainActor.run { self.emailsByAccount = [:] } }
            return
        }
        print("Starting fetch for all account inboxes (fetching threads)...")
        isFetchingEmails = true
        errorMessage = nil

        // --- Clear existing data for a fresh fetch --- 
        self.emailsByAccount = [:]
        self.nextPageTokens = [:]
        // --- End Clear ---

        // Use a TaskGroup to fetch for all accounts concurrently
        Task {
            var allFetchedEmailsByAccount: [String: [EmailDisplayData]] = [:] // Temporary dictionary
            var fetchError: Error? = nil

            // --- Capture filter state before entering TaskGroup --- 
            let currentAccountFilter = self.selectedAccountFilter
            let currentLabelFilter = self.selectedLabelFilter
            // --- End capture --- 

            await withTaskGroup(of: (String, Result<([GTLRGmail_Thread], String?), Error>).self) { group in
                for account in addedAccounts {
                    group.addTask {
                        // Determine fetch parameters based on selected filters
                        var fetchLabelIds: [String]? = nil
                        var fetchSearchQuery: String? = nil

                        // Apply filters ONLY if this account is the selected one
                        // OR if no account is selected (All Inboxes)
                        // Use the captured filter state here
                        if currentAccountFilter == nil || currentAccountFilter == account.emailAddress {
                            if let selectedLabel = currentLabelFilter {
                                fetchLabelIds = [selectedLabel]
                            } else {
                                // If account is selected but no label, fetch "All Mail" for that account
                                // If no account selected (All Inboxes), also fetch "All Mail" for this account
                                fetchSearchQuery = "-label:spam -label:trash"
                            }
                        } else {
                            // If this account isn't selected, don't fetch anything for it in this context
                            // (or fetch default like INBOX if needed later)
                            // Returning empty success to avoid breaking the group structure
                            return (account.emailAddress, .success(([], nil))) 
                        }
                        
                        // Use await for the async fetch call with parameters
                        let result = await self.fetchThreadsForAccountAsync(account: account, labelIds: fetchLabelIds, searchQuery: fetchSearchQuery)
                        return (account.emailAddress, result)
                    }
                }

                // Collect results from the group
                for await (accountEmail, result) in group {
                    switch result {
                    case .success(let threads):
                        print("Successfully fetched \(threads.0.count) threads for \(accountEmail). Processing...")
                        // Map threads, passing the account email
                        let mappedEmails = self.mapAndStructureThreads(threads.0, for: accountEmail)
                        allFetchedEmailsByAccount[accountEmail] = mappedEmails
                        print("Finished processing threads for \(accountEmail). Count: \(mappedEmails.count)")
                        self.nextPageTokens[accountEmail] = threads.1
                    case .failure(let error):
                        print("Failed to fetch threads for \(accountEmail): \(error.localizedDescription)")
                        fetchError = error // Store the first encountered error
                    }
                }
            }

            // Update state on the main thread after all fetches complete
            await MainActor.run {
                self.isFetchingEmails = false
                // Update the main dictionary with the fetched results
                self.emailsByAccount = allFetchedEmailsByAccount
                
                if let error = fetchError {
                    // Optionally, set a general error message if any fetch failed
                    self.errorMessage = "Failed to load some emails: \(error.localizedDescription)"
                }
                // TODO: Re-evaluate if mock injection is still needed here
                // self.injectMockThread() // Inject mock after fetching real data
            }
        }
    }

    // Async helper to fetch threads for a single account
    // Updated to accept labelIds and searchQuery
    private func fetchThreadsForAccountAsync(account: EmailAccount, labelIds: [String]? = nil, searchQuery: String? = nil, pageToken: String? = nil) async -> Result<([GTLRGmail_Thread], String?), Error> {
        await withCheckedContinuation { continuation in
            // Pass parameters to the service
            GmailAPIService.shared.fetchInboxThreads(for: account, labelIds: labelIds, searchQuery: searchQuery, pageToken: pageToken, maxTotalThreads: 50) { result in // Limit threads per account
                continuation.resume(returning: result)
            }
        }
    }
    
    // --- Updated Thread Processing Logic ---
    private func mapAndStructureThreads(_ threads: [GTLRGmail_Thread], for accountEmail: String) -> [EmailDisplayData] {
        var structuredEmails: [EmailDisplayData] = []

        for thread in threads {
            guard let messages = thread.messages, !messages.isEmpty else { continue }

            // Map all messages in the thread, passing the account email
            var mappedMessages = messages.compactMap { self.mapGTLRMessageToEmailDisplayData($0, accountEmail: accountEmail) }
            
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
        // Define a mock account email for the mock thread
        let mockAccountEmail = "mock.user@example.com"
        
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
            previousMessages: nil,
            accountEmail: mockAccountEmail, // Add mock account email
            labelIds: nil // No label IDs for mock original
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
            previousMessages: [mockOriginal],
            accountEmail: mockAccountEmail, // Add mock account email
            labelIds: nil // No label IDs for mock reply
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
            previousMessages: [mockReply1],
            accountEmail: mockAccountEmail, // Add mock account email
            labelIds: nil // No label IDs for mock reply
        )
        
        // Update the dictionary for the mock account
        var currentMocks = self.emailsByAccount[mockAccountEmail] ?? []
        // Remove any previous mock thread from this account's list
        currentMocks.removeAll { $0.threadId == "mockThread1" }
        // Insert mock thread at the top of this account's list
        currentMocks.insert(mockReply2, at: 0)
        // Update the dictionary
        self.emailsByAccount[mockAccountEmail] = currentMocks
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

    // Mapping function - Add accountEmail parameter
    private func mapGTLRMessageToEmailDisplayData(_ gtlrMessage: GTLRGmail_Message, accountEmail: String) -> EmailDisplayData? { // Renamed & added param
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
            previousMessages: nil, // Not fetched with metadata
            accountEmail: accountEmail, // Assign the account email
            labelIds: gtlrMessage.labelIds // Assign label IDs from the message
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

    // Fetches for a single account (called when adding account) - Updated Logic
    private func fetchInboxMessages(for account: EmailAccount) {
        // Fetch specifically for the new account and add to the dictionary
        print("Fetching inbox for newly added account: \(account.emailAddress)")
        
        // Use a Task to perform the fetch asynchronously
        Task {
            // Fetch only the INBOX when adding a new account
            let result = await fetchThreadsForAccountAsync(account: account, labelIds: ["INBOX"])
            
            // Update state on the main thread
            await MainActor.run {
                // Remove this line - token will be set/cleared by the result processing
                // self.nextPageTokens[account.emailAddress] = nil 
                
                switch result {
                case .success(let threads): // threads is ([GTLRGmail_Thread], String?)
                    print("Fetched \(threads.0.count) threads for new account \(account.emailAddress). Mapping...")
                    let mappedEmails = self.mapAndStructureThreads(threads.0, for: account.emailAddress)
                    // Merge new emails with existing emails for this account
                    var currentEmails = self.emailsByAccount[account.emailAddress] ?? []
                    // Basic merging: Add new emails, avoid duplicates based on gmailMessageId
                    let existingIds = Set(currentEmails.map { $0.gmailMessageId })
                    for newEmail in mappedEmails {
                        if !existingIds.contains(newEmail.gmailMessageId) {
                            currentEmails.append(newEmail)
                        }
                    }
                    // Sort the combined list for the account
                    currentEmails.sort { $0.date > $1.date }
                    self.emailsByAccount[account.emailAddress] = currentEmails
                    // --- Store the next page token --- 
                    self.nextPageTokens[account.emailAddress] = threads.1
                    print("Updated inbox for \(account.emailAddress). Total emails: \(currentEmails.count). Next Token: \(threads.1 ?? "nil")")
                case .failure(let error):
                    print("Failed fetch for new account \(account.emailAddress): \(error.localizedDescription)")
                    // Clear token on failure
                    self.nextPageTokens[account.emailAddress] = nil
                    // Optionally set an error message specific to this account or a general one
                    self.errorMessage = "Failed to load emails for \(account.emailAddress): \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Pagination Logic

    func fetchMoreEmailsIfNeeded(currentItem item: EmailDisplayData?) {
        guard let item = item else {
            // If item is nil, maybe fetch if list is very short and token exists?
            // For now, require an item to trigger pagination.
            return
        }

        let thresholdIndex = inboxEmails.index(inboxEmails.endIndex, offsetBy: -5) // Trigger fetch 5 items from end
        if inboxEmails.firstIndex(where: { $0.id == item.id }) == thresholdIndex {
            
            // Determine the account key to check for page token
            // Use selectedAccountFilter if set, otherwise maybe handle "All Inboxes" differently?
            // For now, pagination primarily works when a single account is selected.
            guard let accountKey = selectedAccountFilter else {
                 print("Pagination: Currently only supported when a single account is selected.")
                 return
            }
            
            // Check if there's a next page token for the current filter and not already fetching
            // --- Add Logging ---
            let tokenForAccount = nextPageTokens[accountKey]
            print("Pagination Check: accountKey=\(accountKey), isFetchingMore=\(isFetchingMoreEmails), storedToken=\(String(describing: tokenForAccount)), tokenIsNotNil=\(tokenForAccount != nil)")
            // --- End Logging ---
            guard let token = nextPageTokens[accountKey], token != nil, !isFetchingMoreEmails else {
                // print("Pagination: No next page token for \(accountKey ?? "All") or already fetching.")
                return
            }
            
            print("Pagination: Threshold reached, fetching next page for \(accountKey) with token: \(token ?? "nil")")
            isFetchingMoreEmails = true

            // Reuse the captured filters from fetchAllInboxMessages if possible?
            // Re-capture or pass filters explicitly. For simplicity, re-capture.
            let currentLabelFilter = self.selectedLabelFilter
            
            Task {
                var fetchLabelIds: [String]? = nil
                var fetchSearchQuery: String? = nil

                if let selectedLabel = currentLabelFilter {
                    fetchLabelIds = [selectedLabel]
                } else {
                    // Fetching more for "All Mail" view for this account
                    fetchSearchQuery = "-label:spam -label:trash"
                }
                
                // Fetch next page for the specific account
                let result = await fetchThreadsForAccountAsync(account: EmailAccount(emailAddress: accountKey, provider: "gmail"), // Need EmailAccount object
                                                             labelIds: fetchLabelIds,
                                                             searchQuery: fetchSearchQuery,
                                                             pageToken: token)
                                                             
                await MainActor.run {
                    self.isFetchingMoreEmails = false
                    switch result {
                    case .success(let (newThreads, nextToken)):
                        print("Pagination: Successfully fetched \(newThreads.count) more threads for \(accountKey).")
                        // Map the new threads
                        let mappedEmails = self.mapAndStructureThreads(newThreads, for: accountKey)
                        // Append to existing list for that account
                        var currentEmails = self.emailsByAccount[accountKey] ?? []
                        let existingIds = Set(currentEmails.map { $0.gmailMessageId })
                        var addedCount = 0
                        for newEmail in mappedEmails {
                            if !existingIds.contains(newEmail.gmailMessageId) {
                                currentEmails.append(newEmail)
                                addedCount += 1
                            }
                        }
                        // Re-sort might be needed if dates are interleaved, but usually append works
                        // currentEmails.sort { $0.date > $1.date }
                        self.emailsByAccount[accountKey] = currentEmails
                        // Store the *new* next page token for this account
                        self.nextPageTokens[accountKey] = nextToken
                        print("Pagination: Appended \(addedCount) new emails for \(accountKey). New next token: \(nextToken ?? "nil")")
                        
                    case .failure(let error):
                        print("Pagination: Failed to fetch next page for \(accountKey): \(error.localizedDescription)")
                        // Clear token on error?
                        self.nextPageTokens[accountKey] = nil 
                        self.errorMessage = "Failed to load more emails."
                    }
                }
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

    // MARK: - Email Actions (Mark Read/Unread, Delete, etc.)

    func markAsRead(email: EmailDisplayData) async {
        // 1. Check if already marked as read locally
        guard email.labelIds?.contains("UNREAD") == true else {
            print("Email \(email.id) is already marked as read locally.")
            return
        }

        // 2. Get the service for the correct account
        guard let account = addedAccounts.first(where: { $0.emailAddress == email.accountEmail }) else {
            print("Error: Could not find account (\(email.accountEmail)) for email \(email.id)") 
            return
        }
        
        print("Attempting to mark email \(email.id) as read for account \(account.emailAddress)")
        
        // 3. Call the NEW Gmail service function to modify labels using async/await
        do {
            // Convert the completion handler based function to async using withCheckedThrowingContinuation
            let _: GTLRGmail_Message = try await withCheckedThrowingContinuation { continuation in
                GmailAPIService.shared.modifyMessageLabels(
                    for: account, 
                    messageId: email.gmailMessageId, // Use the actual Gmail message ID
                    addLabelIds: [], // No labels to add
                    removeLabelIds: ["UNREAD"] // Label ID to remove
                ) { result in
                    switch result {
                    case .success(let message):
                        continuation.resume(returning: message)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // 4. Update local state on success
            print("Successfully marked email \(email.id) as read via API.")
            let accountEmail = email.accountEmail 
            // Ensure the array exists and make a mutable copy
            if var emailsForAccount = emailsByAccount[accountEmail],
               let index = emailsForAccount.firstIndex(where: { $0.id == email.id }) {
                
                // Modify the properties directly on the struct within the copied array
                emailsForAccount[index].labelIds?.removeAll { $0 == "UNREAD" }
                emailsForAccount[index].isRead = true // Explicitly set isRead to true
                
                // Reassign the entire modified array back to the dictionary
                // This ensures SwiftUI detects the change while preserving item identity.
                emailsByAccount[accountEmail] = emailsForAccount
                print("Updated local email state for \(email.id) (isRead=true). Modified instance in copied array for account \(accountEmail).")
            } else {
                print("Warning: Could not find email \(email.id) in local cache (\(accountEmail)) to update state after marking read.") 
            }
            
        } catch { // Catch errors from the async call
            print("Error marking email \(email.id) as read: \(error.localizedDescription)")
            errorMessage = "Failed to mark email as read."
        }
    }

    // TODO: Add functions for markAsUnread, deleteEmail, archiveEmail, etc.

    // MARK: - Filtered Fetching

    func fetchMessagesForCurrentFilter() async {
        guard let accountEmail = selectedAccountFilter else {
            print("Filter Fetch: Cannot fetch, no account selected.")
            // If no account is selected, it implies "All Inboxes". 
            // We might need to refresh all inboxes here, similar to fetchAllInboxMessages.
            // For now, we only handle fetches when a specific account is selected.
            // Consider calling fetchAllInboxMessages() if appropriate for 'All Inboxes'.
            return 
        }
        
        guard let account = addedAccounts.first(where: { $0.emailAddress == accountEmail }) else {
            print("Filter Fetch: Account object not found for \\(accountEmail)")
            return
        }

        // Determine label IDs to fetch based on selectedLabelFilter
        var labelIdsToFetch: [String]? = nil
        var fetchDescription = "" // For logging
        if let labelId = selectedLabelFilter {
            labelIdsToFetch = [labelId]
            fetchDescription = "label '\\(labelId)'"
        } else {
            // If no specific label is selected for the account, what should we fetch?
            // Option 1: Default to INBOX
            // labelIdsToFetch = ["INBOX"] 
            // fetchDescription = "default INBOX"
            // Option 2: Fetch "All Mail" (excluding spam/trash) - Requires different query?
            // For now, let's assume if selectedLabelFilter is nil for a specific account,
            // it means "All Mail" for that account. The API call might need adjustment.
            // Let's default to fetching INBOX if no label is selected, for simplicity now.
             labelIdsToFetch = ["INBOX"] // Defaulting to INBOX for now if filter is nil
             fetchDescription = "default INBOX (nil filter)"
            print("Filter Fetch: No specific label selected for \\(accountEmail). Defaulting to fetch INBOX.")
        }
        
        print("Filter Fetch: Starting fetch for account \\(accountEmail), \(fetchDescription)")
        
        await MainActor.run { // Ensure UI updates happen on main thread
             isFetchingEmails = true
             errorMessage = nil
             // Clear previous emails for *this account* before fetching new filter results
             // This prevents showing stale data while fetching.
             emailsByAccount[accountEmail] = [] 
             nextPageTokens[accountEmail] = nil // Reset pagination for the new filter
        }

        // Fetch threads for the specific account and label
        let result = await fetchThreadsForAccountAsync(account: account, labelIds: labelIdsToFetch)
        
        // Update state on the main thread
        await MainActor.run {
            isFetchingEmails = false // Fetch complete
            switch result {
            case .success(let (threads, nextPageToken)):
                print("Filter Fetch: Successfully fetched \\(threads.count) threads for \\(accountEmail), \(fetchDescription). Mapping...")
                let mappedEmails = self.mapAndStructureThreads(threads, for: accountEmail)
                // Replace the emails for this account with the newly fetched ones
                emailsByAccount[accountEmail] = mappedEmails
                nextPageTokens[accountEmail] = nextPageToken // Store new pagination token
                // Fix interpolation for optional token
                print("Filter Fetch: Updated cache for \\(accountEmail). Total: \\(mappedEmails.count). Next Token: \(String(describing: nextPageToken))")

            case .failure(let error):
                print("Filter Fetch: Failed fetch for \\(accountEmail), \(fetchDescription): \(error.localizedDescription)")
                errorMessage = "Failed to load emails for selected filter."
                // Keep the account's email list empty on failure? Or revert? Empty is simpler.
                emailsByAccount[accountEmail] = [] 
                nextPageTokens[accountEmail] = nil
            }
        }
    }
} 