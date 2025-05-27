import Foundation
import Combine
import Supabase
import AuthenticationServices
import SwiftUI
import GoogleSignIn
import GoogleAPIClientForREST_Gmail
import SwiftData

@MainActor
class UserViewModel: ObservableObject {
    // SwiftData ModelContext
    private var modelContext: ModelContext?

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
    
    // Auth service (make internal - remove private)
    /* private */ var authService: AuthenticationService?
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
            .receive(on: DispatchQueue.main) // Ensure main thread
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        // Subscribe to current user changes (now Supabase User)
        authService?.$currentUser
            .receive(on: DispatchQueue.main) // Ensure main thread
            .sink { [weak self] supabaseUser in
                guard let self = self else { return }
                
                self.userEmail = supabaseUser?.email
                self.userName = supabaseUser?.userMetadata["full_name"] as? String ?? supabaseUser?.userMetadata["name"] as? String
                print("ViewModel Updated: Email=\(self.userEmail ?? "nil"), Name=\(self.userName ?? "nil")")
                
                if let supabaseUser = supabaseUser {
                    // Save last used userId/email for offline use
                    UserDefaults.standard.set(supabaseUser.id.uuidString, forKey: self.lastUsedUserIdKey)
                    UserDefaults.standard.set(supabaseUser.email, forKey: self.lastUsedUserEmailKey)
                    print("User logged in, loading accounts...")
                    Task {
                        await self.loadAccounts()
                        // Don't necessarily fetch all emails immediately after loading accounts from DB
                        // Let user interaction or a background sync trigger this.
                        // await self.fetchAllInboxMessages() 
                    }
                } else {
                    print("User logged out, clearing accounts...")
                    // No await needed here, already on main thread
                    self.addedAccounts = []
                    self.emailsByAccount = [:]
                    self.labelsByAccount = [:]
                    self.nextPageTokens = [:]
                }
            }
            .store(in: &cancellables)
        
        // Remove direct Firebase check
        // if FirebaseApp.app() != nil { ... }

        // Initial load/fetch is now handled by the sink above when the first auth state is received
        // loadAccounts() 
        // fetchAllInboxMessages()

        // Always load from SwiftData on init
        Task { await self.loadAccountsFromSwiftDataOfflineFallback() }
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
    
    func addAccount(email: String, provider: String, refreshToken: String) {
        // 1. Ensure user is authenticated
        guard let userId = authService?.currentUser?.id else {
            print("Error adding account: User not authenticated.")
            self.errorMessage = "Authentication required to add accounts."
            return
        }
        
        // 2. Prepare the account data for insertion
        // Note: We don't need to check addedAccounts locally first, 
        // the database primary key (user_id, email_address) will prevent duplicates.
        let newAccount = EmailAccount(userId: userId, emailAddress: email, provider: provider)
        // Optional: You could set accountName here if you fetched it during OAuth
        // newAccount.accountName = fetchedName 

        print("Attempting to add account \(email) to database for user \(userId).")
        
        Task {
            do {
                // 3. Insert into Supabase 'accounts' table
                // We pass the whole 'newAccount' object because it's Codable
                // and matches the table structure (thanks to CodingKeys)
                _ = try await supabase
                    .from("accounts")
                    .insert(newAccount) // Pass the Codable struct
                    .execute()
                
                print("Successfully inserted account \(email) into database.")
                
                // 4. Reload accounts from database to update local state
                // Ensure loadAccounts is called on main actor if it updates @Published properties
                await loadAccounts() // Assuming loadAccounts handles main actor update
                
                // 5. Fetch emails/labels for the new account (already done by loadAccounts now)
                // if let newlyLoadedAccount = self.addedAccounts.first(where: { $0.emailAddress == email }) {
                //    fetchInboxMessages(for: newlyLoadedAccount)
                //    fetchLabels(for: newlyLoadedAccount)
                // }
                
            } catch {
                print("Error inserting account \(email) into database: \(error.localizedDescription)")
                // Add await here
                await MainActor.run {
                     self.errorMessage = "Failed to save account: \(error.localizedDescription)"
                 }
            }
        }
    }
    
    func removeAccount(account: EmailAccount) {
        // 1. Ensure user is authenticated and we have the target account details
        guard let userId = authService?.currentUser?.id else {
            print("Error removing account: User not authenticated.")
            self.errorMessage = "Authentication required to remove accounts."
            return
        }
        let emailToDelete = account.emailAddress
        print("Attempting to remove account \(emailToDelete) from database for user \(userId).")

        Task {
            do {
                // 2. Delete refresh token from Keychain (keep this local operation)
                let deleteSuccessful = KeychainService.deleteToken(account: emailToDelete)
                if !deleteSuccessful {
                    print("Warning: Failed to delete token from keychain for \(emailToDelete), but proceeding with DB delete.")
                }
                
                // 3. Delete from Supabase 'accounts' table
                _ = try await supabase
                    .from("accounts")
                    .delete()
                    .match(["user_id": userId.uuidString, "email_address": emailToDelete]) // Match on composite key
                    .execute()
                
                print("Successfully deleted account \(emailToDelete) from database.")
                
                // 4. Reload accounts from database to update local state
                await loadAccounts()
                
            } catch {
                print("Error deleting account \(emailToDelete) from database: \(error.localizedDescription)")
                 // Add await here
                 await MainActor.run {
                    self.errorMessage = "Failed to remove account: \(error.localizedDescription)"
                 }
            }
        }
    }
    
    // Updated to load accounts from Supabase database and marked async
    private func loadAccounts() async {
        guard let userId = authService?.currentUser?.id else {
            print("Skipping loadAccounts: User not authenticated.")
            self.addedAccounts = [] 
            self.labelsByAccount = [:] // Clear cache on logout
            self.emailsByAccount = [:] // Clear cache on logout
            return
        }
        
        print("Attempting to load accounts from database for user: \(userId)")
        
        do {
            // 1. Fetch Accounts from DB
            let loadedAccounts: [EmailAccount] = try await supabase
                .from("accounts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value 

            // 2. Update local accounts state (already on MainActor)
            self.addedAccounts = loadedAccounts
            print("Successfully loaded \(loadedAccounts.count) accounts from database.")
            
            // 3. Load cached Labels & Emails from DB *first*
            if !loadedAccounts.isEmpty {
                await loadLabelsFromDatabase(for: userId)
                await loadEmailsFromDatabase(for: userId)
            } else {
                 // Ensure caches are clear if no accounts found in DB
                 self.labelsByAccount = [:]
                 self.emailsByAccount = [:]
            }
            
            // 4. *Then*, trigger background API fetches for fresh data & sync
            // These will update the UI state again and sync to DB
            print("Triggering API fetches for labels and emails...")
            for account in loadedAccounts {
                // fetchLabels handles its own Task/async
                self.fetchLabels(for: account)
            }
            // fetchAllInboxMessages handles its own Task/async
            self.fetchAllInboxMessages() 
            
        } catch {
            print("Error loading accounts from database: \(error.localizedDescription)")
            self.errorMessage = "Failed to load saved accounts: \(error.localizedDescription)"
            self.addedAccounts = [] 
            self.labelsByAccount = [:] // Clear cache on error
            self.emailsByAccount = [:] // Clear cache on error
        }
    }
    
    // MARK: - Account Persistence (Remove UserDefaults logic)
    
    // Remove userDefaultsKeyForAccounts computed property
    /*
    private var userDefaultsKeyForAccounts: String {
        // ... removed ...
    }
    */

    // Remove saveAccounts function
    /*
    private func saveAccounts() {
        // ... removed ...
    }
    */
    
    // MARK: - Label Fetching

    func fetchLabels(for account: EmailAccount) {
        let accountEmail = account.emailAddress
        guard let userId = authService?.currentUser?.id else {
            print("Cannot fetch labels: User not authenticated.")
             return
        }
        
        // If we already have labels for this account, don't set loading state to avoid UI flickering
        let hasCachedLabels = labelsByAccount[accountEmail]?.isEmpty == false
        
        if !hasCachedLabels {
            // Only show loading indicator if we don't have any cached labels
            isFetchingLabels[accountEmail] = true
        }
        
        print("Fetching labels for \(accountEmail) from Gmail API...")
        
        GmailAPIService.shared.fetchLabels(for: account) { [weak self] result in
            Task {
                // Use a single guard to unwrap self for the whole Task scope
                    guard let self = self else { return }
                
                // Update fetching state on MainActor
                await MainActor.run { 
                    self.isFetchingLabels[accountEmail] = false 
                }
                
                    switch result {
                case .success(let fetchedGtlrLabels):
                    // If we have existing labels and the fetched ones are the same, don't update UI
                    if let existingLabels = self.labelsByAccount[accountEmail], !existingLabels.isEmpty {
                        // Only update if there's a meaningful difference to avoid UI flickering
                        let existingIds = Set(existingLabels.compactMap { $0.identifier })
                        let newIds = Set(fetchedGtlrLabels.compactMap { $0.identifier })
                        
                        if existingIds == newIds {
                            print("Labels for \(accountEmail) unchanged, skipping UI update")
                            // Still sync to database in background
                            Task {
                                await self.syncLabelsToDatabase(userId: userId, accountEmail: accountEmail, labels: fetchedGtlrLabels)
                            }
                            return
                        }
                    }
                    
                    // If we get here, we need to update the UI with new labels
                    await MainActor.run { 
                        self.labelsByAccount[accountEmail] = fetchedGtlrLabels
                        print("Successfully fetched \(fetchedGtlrLabels.count) labels from Gmail API for \(accountEmail).")
                    }
                    
                    // Sync to Supabase (can happen in background Task)
                    await self.syncLabelsToDatabase(userId: userId, accountEmail: accountEmail, labels: fetchedGtlrLabels)
                    
                case .failure(let error):
                    // Handle API fetch error on MainActor
                     await MainActor.run {
                        print("Failed to fetch labels from Gmail API for \(accountEmail): \(error.localizedDescription)")
                        self.errorMessage = "Failed to load folders for \(accountEmail)."
                    }
                }
            }
        }
    }
    
    // Helper method to sync labels to database
    private func syncLabelsToDatabase(userId: UUID, accountEmail: String, labels: [GTLRGmail_Label]) async {
        do {
            let supabaseLabels = labels.compactMap { gtlrLabel -> SupabaseLabel? in
                guard let providerId = gtlrLabel.identifier, 
                      let name = gtlrLabel.name, 
                      let type = gtlrLabel.type else { return nil }
                return SupabaseLabel(userId: userId, 
                                   accountEmail: accountEmail, 
                                   providerLabelId: providerId, 
                                   name: name, 
                                   type: type)
            }
            
            guard !supabaseLabels.isEmpty else {
                print("No valid labels to sync to Supabase for \(accountEmail).")
                return
            }
            
            print("Attempting to upsert \(supabaseLabels.count) labels to Supabase for \(accountEmail)...")
            _ = try await supabase
                .from("labels")
                .upsert(supabaseLabels)
                .execute()
            print("Successfully upserted labels to Supabase for \(accountEmail).")
            
        } catch {
            print("Error upserting labels to Supabase for \(accountEmail): \(error.localizedDescription)")
            // We don't update the UI error message here since this is a background operation
        }
    }

    // MARK: - Email Fetching
    
    func fetchAllInboxMessages() {
        Task {
            await fetchAllInboxMessagesAsync()
        }
    }
    
    private func fetchAllInboxMessagesAsync() async {
        guard !isFetchingEmails else { return }
        guard let userId = authService?.currentUser?.id else {
            print("Cannot fetch emails: User not authenticated.")
            return
        }
        guard !addedAccounts.isEmpty else {
            print("No accounts configured. Skipping fetch.")
            await MainActor.run { self.emailsByAccount = [:] }
            return
        }
        
        // Capture the current filter state
        let currentAccountFilter = self.selectedAccountFilter
        let currentLabelFilter = self.selectedLabelFilter
        let filterDescription = currentLabelFilter != nil ? "Label: \(currentLabelFilter!)" : "All Mail"
        
        print("Starting fetch for \(currentAccountFilter == nil ? "all accounts" : currentAccountFilter!), \(filterDescription)...")
        
        await MainActor.run {
            isFetchingEmails = true
            errorMessage = nil
            self.emailsByAccount = [:]
            self.nextPageTokens = [:]
        }

        var allFetchedEmailsByAccount: [String: [EmailDisplayData]] = [:] 
        var allSupabaseEmails: [SupabaseEmail] = [] // To collect emails for DB
        var allSupabaseEmailLabelLinks: [SupabaseEmailLabelLink] = [] // To collect links for DB
        var fetchError: Error? = nil

        await withTaskGroup(of: (String, Result<([GTLRGmail_Thread], String?), Error>).self) { group in
            for account in addedAccounts {
                // Skip accounts that don't match the current filter, if one is selected
                if let accountFilter = currentAccountFilter, accountFilter != account.emailAddress {
                    continue
                }
                
                group.addTask {
                    // Determine fetch parameters based on selected filters
                    var fetchLabelIds: [String]? = nil
                    var fetchSearchQuery: String? = nil
                    
                    if let selectedLabel = currentLabelFilter {
                        fetchLabelIds = [selectedLabel]
                        print("Fetching label \(selectedLabel) for account \(account.emailAddress)")
                    } else {
                        // Default to fetching all mail except spam/trash
                        fetchSearchQuery = "-label:spam -label:trash"
                        print("Fetching All Mail for account \(account.emailAddress)")
                    }
                    
                    let result = await self.fetchThreadsForAccountAsync(account: account, labelIds: fetchLabelIds, searchQuery: fetchSearchQuery)
                    return (account.emailAddress, result)
                }
            }

            // Collect results and map for DB
            for await (accountEmail, result) in group {
                switch result {
                case .success(let (threads, nextPageToken)):
                    print("Successfully fetched \(threads.count) threads for \(accountEmail). Processing...")
                    
                    // --- Map for UI (existing logic) ---
                    let mappedEmailsForUI = self.mapAndStructureThreads(threads, for: accountEmail)
                    allFetchedEmailsByAccount[accountEmail] = mappedEmailsForUI
                    await MainActor.run { self.nextPageTokens[accountEmail] = nextPageToken }
                    // --- End UI Mapping ---
                    
                    // --- Map for Database --- 
                    for thread in threads {
                        guard let messages = thread.messages else { continue }
                        for message in messages {
                            if let supabaseData = self.mapGTLRMessageToSupabaseData(message, userId: userId, accountEmail: accountEmail) {
                                allSupabaseEmails.append(supabaseData.email)
                                allSupabaseEmailLabelLinks.append(contentsOf: supabaseData.labelLinks)
                            }
                        }
                    }
                    // --- End DB Mapping ---
                    
                    print("Finished processing threads for \(accountEmail). UI Count: \(mappedEmailsForUI.count)")
                    
                case .failure(let error):
                    print("Failed to fetch threads for \(accountEmail): \(error.localizedDescription)")
                    fetchError = error
                }
            }
        }

        // Update UI state on the main thread
        await MainActor.run {
            self.isFetchingEmails = false
            self.emailsByAccount = allFetchedEmailsByAccount // Update UI
            if let error = fetchError {
                self.errorMessage = "Failed to load some emails: \(error.localizedDescription)"
            }
        }
        
        // --- Upsert data to Supabase in the background --- 
        if !allSupabaseEmails.isEmpty {
            print("Attempting to upsert \(allSupabaseEmails.count) emails to Supabase...")
            do {
                _ = try await supabase.from("emails").upsert(allSupabaseEmails).execute()
                print("Successfully upserted emails to Supabase.")
                // ADD: Save to SwiftData after upsert
                await saveEmailsToSwiftData(supabaseEmails: allSupabaseEmails, for: userId)
            } catch {
                print("Error upserting emails to Supabase: \(error.localizedDescription)")
            }
        }
        
        if !allSupabaseEmailLabelLinks.isEmpty {
            print("Attempting to upsert \(allSupabaseEmailLabelLinks.count) email-label links to Supabase...")
             do {
                _ = try await supabase.from("email_labels").upsert(allSupabaseEmailLabelLinks).execute()
                print("Successfully upserted email-label links.")
            } catch {
                print("Error upserting email-label links to Supabase: \(error.localizedDescription)")
            }
        }
        // --- End Supabase Upsert --- 
    }

    // Async helper to fetch threads for a single account
    // Updated to accept labelIds and searchQuery
    private func fetchThreadsForAccountAsync(account: EmailAccount, labelIds: [String]? = nil, searchQuery: String? = nil, pageToken: String? = nil) async -> Result<([GTLRGmail_Thread], String?), Error> {
        await withCheckedContinuation { continuation in
            // Pass parameters to the service
            GmailAPIService.shared.fetchInboxThreads(for: account, labelIds: labelIds, searchQuery: searchQuery, pageToken: pageToken, maxTotalThreads: 50) { result in
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
            
            if mappedMessages.isEmpty { continue }
            
            // Build the nested structure - all previous messages will be in the history of the most recent one
            var history: [EmailDisplayData] = []
            var newestMessage: EmailDisplayData? = nil
            
            // Process all but the last message as history
            for i in 0..<(mappedMessages.count - 1) {
                history.append(mappedMessages[i])
            }
            
            // Get the most recent message (last in time-sorted array)
            if let lastMessage = mappedMessages.last {
                var mostRecentMessage = lastMessage
                mostRecentMessage.previousMessages = history.isEmpty ? nil : history
                newestMessage = mostRecentMessage
            }

            // Add the most recent message (which now contains the history) to the final list
            if let messageToShow = newestMessage {
                structuredEmails.append(messageToShow)
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

    // --- NEW: Helper function to map GTLR Message to Supabase Data --- 
    private func mapGTLRMessageToSupabaseData(_ gtlrMessage: GTLRGmail_Message, userId: UUID, accountEmail: String) -> (email: SupabaseEmail, labelLinks: [SupabaseEmailLabelLink])? {
        guard let providerMessageId = gtlrMessage.identifier else { return nil }
        
        // Extract date (prioritize internalDate)
        var dateReceived: Date
        if let internalDateMillis = gtlrMessage.internalDate?.int64Value {
             dateReceived = Date(timeIntervalSince1970: TimeInterval(internalDateMillis) / 1000.0)
        } else if let dateHeaderString = gtlrMessage.payload?.headers?.first(where: { $0.name?.uppercased() == "DATE" })?.value,
                  let parsedDate = parseDateHeader(dateHeaderString) {
            dateReceived = parsedDate
        } else {
            print("Warning: Using current date for email \(providerMessageId) as no valid date found.")
            dateReceived = Date() // Fallback
        }

        // Extract other headers and details
        var senderName: String? = nil
        var senderEmail: String? = nil
        var recipientTo: String? = nil // Simplified for now
        var subject: String? = nil
        var messageIdHeader: String? = nil
        var referencesHeader: String? = nil

        if let headers = gtlrMessage.payload?.headers {
            for header in headers {
                guard let name = header.name, let value = header.value else { continue }
                switch name.uppercased() {
                case "SUBJECT": subject = value
                case "FROM": 
                    let components = value.components(separatedBy: "<")
                    senderName = components.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if components.count > 1, let emailPart = components.last?.trimmingCharacters(in: [">", " "]) {
                        senderEmail = emailPart
                    } else if value.contains("@") { senderEmail = value }
                case "TO": recipientTo = value // Keep full To header for now
                case "MESSAGE-ID": messageIdHeader = value
                case "REFERENCES": referencesHeader = value
                default: break
                }
            }
        }
        
        let supabaseEmail = SupabaseEmail(
            userId: userId,
            accountEmail: accountEmail,
            providerMessageId: providerMessageId,
            threadId: gtlrMessage.threadId,
            messageIdHeader: messageIdHeader,
            referencesHeader: referencesHeader,
            senderName: senderName,
            senderEmail: senderEmail,
            recipientTo: recipientTo,
            recipientCc: nil, // TODO: Parse CC if needed
            recipientBcc: nil, // TODO: Parse BCC if needed
            subject: subject,
            snippet: gtlrMessage.snippet,
            dateReceived: dateReceived,
            isRead: !(gtlrMessage.labelIds?.contains("UNREAD") ?? false),
            // Simplification: Check if payload indicates parts exist, actual attachment download is separate
            hasAttachments: (gtlrMessage.payload?.parts?.contains(where: { $0.filename != nil && !$0.filename!.isEmpty }) ?? false)
            // createdAt/updatedAt are set by DB
        )
        
        // Create Email-Label Links
        let actualLabelIds = gtlrMessage.labelIds ?? []
        let labelLinks = actualLabelIds.map {
            SupabaseEmailLabelLink(userId: userId,
                                   accountEmail: accountEmail, 
                                   providerMessageId: providerMessageId, 
                                   providerLabelId: $0)
        }
        
        // Assign labelIds to the supabaseEmail object for transient use
        var mutableSupabaseEmail = supabaseEmail
        mutableSupabaseEmail.labelIds = actualLabelIds
        
        return (mutableSupabaseEmail, labelLinks)
    }
    // --- End DB Mapping Helper --- 

    // Remove old mapping function if no longer needed, or keep for UI if structure differs significantly
    // private func mapGTLRMessageToEmailDisplayData(...) -> EmailDisplayData? { ... }
    // NOTE: mapAndStructureThreads still uses mapGTLRMessageToEmailDisplayData for the UI model.
    // We need to decide if we want one mapping function returning both UI and DB models,
    // or keep them separate. Keeping separate for now is less disruptive.
    private func mapGTLRMessageToEmailDisplayData(_ gtlrMessage: GTLRGmail_Message, accountEmail: String) -> EmailDisplayData? { 
        // ... (Keep existing implementation as it maps to the UI model EmailDisplayData) ...
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
            // Use selectedAccountFilter if set, otherwise handle "All Inboxes" differently?
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
            // No need to set isLoading = false here, the auth state listener will trigger UI updates
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
             // No need to set isLoading = false here
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }

    // signOut needs to be async now
    func signOut() async { // Changed to async
        guard let authService = authService else { 
            handleError(.unknown(message: "AuthService not initialized"))
            return
        }
        // Set isLoading to true for sign out
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signOut() // Call async version
            // Manually reset loading state after signOut
            isLoading = false
            // State clearing is handled by the auth state listener's sink block
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
            isLoading = false // Keep isLoading updates for non-state-change actions
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
            // No need to set isLoading = false here
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
        isLoading = false // Ensure loading state is reset on error
        
        switch error {
        case .signInError(let message),
             .signUpError(let message),
             .signOutError(let message),
             .resetPasswordError(let message),
             .appleSignInError(let message),
             .unknown(let message):
            errorMessage = message
        case .userNotFound: // May map to specific Supabase errors if needed
            errorMessage = "User not found or invalid credentials."
        case .invalidCredentials: // Covered by Supabase errors generally
            errorMessage = "Invalid credentials. Please try again."
        }
         print("Auth Error Handled: \(errorMessage ?? "No message")")
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
        guard authService?.currentUser != nil else {
            print("Cannot fetch emails: User not authenticated.")
            return
        }
        
        // If no account is selected, it means "All Inboxes" (combined view)
        if selectedAccountFilter == nil {
            // For "All Inboxes", use fetchAllInboxMessages which handles filtering across all accounts
            print("Filter Fetch: No account selected, fetching emails for All Inboxes")
            fetchAllInboxMessages()
            return
        }
        
        let accountEmail = selectedAccountFilter!
        
        guard let account = addedAccounts.first(where: { $0.emailAddress == accountEmail }) else {
            print("Filter Fetch: Account object not found for \(accountEmail)")
            return
        }

        // Determine label IDs to fetch based on selectedLabelFilter
        var labelIdsToFetch: [String]? = nil
        var fetchDescription = "" // For logging
        if let labelId = selectedLabelFilter {
            labelIdsToFetch = [labelId]
            fetchDescription = "label '\(labelId)'"
        } else {
            // Use a search query for "All Mail" instead of default INBOX
            // This way we get all messages except trash and spam
            labelIdsToFetch = nil
            fetchDescription = "All Mail"
            print("Filter Fetch: No specific label selected for \(accountEmail). Fetching All Mail.")
        }
        
        print("Filter Fetch: Starting fetch for account \(accountEmail), \(fetchDescription)")
        
        await MainActor.run { // Ensure UI updates happen on main thread
             isFetchingEmails = true
             errorMessage = nil
             // Clear previous emails for *this account* before fetching new filter results
             // This prevents showing stale data while fetching.
             emailsByAccount[accountEmail] = [] 
             nextPageTokens[accountEmail] = nil // Reset pagination for the new filter
        }

        // Fetch threads for the specific account and label
        let result = await fetchThreadsForAccountAsync(account: account, labelIds: labelIdsToFetch, 
                                                     searchQuery: labelIdsToFetch == nil ? "-label:spam -label:trash" : nil)
        
        // Update state on the main thread
        await MainActor.run {
            isFetchingEmails = false // Fetch complete
            switch result {
            case .success(let (threads, nextPageToken)):
                print("Filter Fetch: Successfully fetched \(threads.count) threads for \(accountEmail), \(fetchDescription). Mapping...")
                let mappedEmails = self.mapAndStructureThreads(threads, for: accountEmail)
                // Replace the emails for this account with the newly fetched ones
                emailsByAccount[accountEmail] = mappedEmails
                nextPageTokens[accountEmail] = nextPageToken // Store new pagination token
                print("Filter Fetch: Updated cache for \(accountEmail). Total: \(mappedEmails.count). Next Token: \(String(describing: nextPageToken))")

            case .failure(let error):
                print("Filter Fetch: Failed fetch for \(accountEmail), \(fetchDescription): \(error.localizedDescription)")
                errorMessage = "Failed to load emails for selected filter."
                // Keep the account's email list empty on failure
                emailsByAccount[accountEmail] = [] 
                nextPageTokens[accountEmail] = nil
            }
        }
    }

    // --- Add the new private functions here ---
    @MainActor
    private func loadLabelsFromDatabase(for userId: UUID) async {
        print("Attempting to load labels from Supabase for user: \(userId)")
        do {
            let storedLabels: [SupabaseLabel] = try await supabase
                .from("labels")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            // Map SupabaseLabel back to GTLRGmail_Label for UI state
            var labelsGrouped: [String: [GTLRGmail_Label]] = [:]
            for labelData in storedLabels {
                let gtlrLabel = GTLRGmail_Label()
                gtlrLabel.identifier = labelData.providerLabelId
                gtlrLabel.name = labelData.name
                gtlrLabel.type = labelData.type
                labelsGrouped[labelData.accountEmail, default: []].append(gtlrLabel)
            }

            self.labelsByAccount = labelsGrouped
            print("Successfully loaded \(storedLabels.count) labels from Supabase into UI state.")

        } catch {
            print("Error loading labels from Supabase: \(error.localizedDescription)")
            self.errorMessage = "Failed to load label cache: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadEmailsFromDatabase(for userId: UUID) async {
        print("Attempting to load emails from Supabase for user: \(userId)")
        do {
            let storedEmails: [SupabaseEmail] = try await supabase
                .from("emails")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("date_received", ascending: false)
                .limit(200) // Add a reasonable limit for initial load
                .execute()
                .value
                
            // Early exit if no emails cached    
            guard !storedEmails.isEmpty else {
                 print("No cached emails found in Supabase.")
                 self.emailsByAccount = [:] // Ensure UI state is cleared
                 return
            }

            // Fetch email-label links for the loaded emails
            let emailIds = storedEmails.map { $0.providerMessageId }
            let storedLinks: [SupabaseEmailLabelLink] = try await supabase
                .from("email_labels")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("provider_message_id", values: emailIds) // Filter links for fetched emails
                .execute()
                .value

            var emailsGrouped: [String: [EmailDisplayData]] = [:]
            var labelsPerMessage: [String: [String]] = [:] 
            for link in storedLinks {
                labelsPerMessage[link.providerMessageId, default: []].append(link.providerLabelId)
            }

            for emailData in storedEmails {
                let displayData = EmailDisplayData(
                    gmailMessageId: emailData.providerMessageId,
                    threadId: emailData.threadId,
                    messageIdHeader: emailData.messageIdHeader,
                    referencesHeader: emailData.referencesHeader,
                    sender: emailData.senderName ?? emailData.senderEmail ?? "Unknown Sender",
                    senderEmail: emailData.senderEmail,
                    recipient: emailData.recipientTo, 
                    subject: emailData.subject ?? "No Subject",
                    snippet: emailData.snippet ?? "",
                    body: "",
                    date: emailData.dateReceived,
                    isRead: emailData.isRead,
                    previousMessages: nil, 
                    accountEmail: emailData.accountEmail,
                    labelIds: labelsPerMessage[emailData.providerMessageId] ?? []
                )
                emailsGrouped[emailData.accountEmail, default: []].append(displayData)
            }
            
            // Sort emails within each account if DB didn't guarantee order
            // for key in emailsGrouped.keys {
            //     emailsGrouped[key]?.sort { $0.date > $1.date }
            // }

            self.emailsByAccount = emailsGrouped
            print("Successfully loaded \(storedEmails.count) emails from Supabase into UI state.")

        } catch {
            print("Error loading emails from Supabase: \(error.localizedDescription)")
            self.errorMessage = "Failed to load email cache: \(error.localizedDescription)"
            self.emailsByAccount = [:] // Clear cache on error
        }
    }
    // --- End new private functions ---

    // --- SwiftData Setup ---
    func setupModelContext(_ context: ModelContext) {
        self.modelContext = context
        // Always load from SwiftData after context is set
        Task { await self.loadAccountsFromSwiftDataOfflineFallback() }
    }
    
    // --- End SwiftData Setup ---

    private func setupAuthCancellable() {
        // ... existing code ...
    }

    // --- New: Load from SwiftData with offline fallback ---
    private func loadAccountsFromSwiftDataOfflineFallback() async {
        guard let context = modelContext else {
            print("ModelContext not available for SwiftData offline load.")
            return
        }
        // Try to get userId from auth, else fallback to UserDefaults
        let userIdString = authService?.currentUser?.id.uuidString ?? UserDefaults.standard.string(forKey: lastUsedUserIdKey)
        var userId: UUID? = nil
        if let userIdString, let uuid = UUID(uuidString: userIdString) { userId = uuid }
        let descriptor: FetchDescriptor<AccountEntity>
        if let userId = userId {
            descriptor = FetchDescriptor<AccountEntity>(predicate: #Predicate { $0.userId == userId })
        } else {
            descriptor = FetchDescriptor<AccountEntity>() // Load all accounts if no userId
        }
        do {
            let storedAccounts = try context.fetch(descriptor)
            let uiAccounts = storedAccounts.map { entity in
                EmailAccount(
                    id: UUID(),
                    userId: entity.userId,
                    emailAddress: entity.emailAddress,
                    provider: entity.provider,
                    accountName: entity.accountName,
                    lastSyncedAt: entity.lastSyncedAt,
                    createdAt: entity.createdAt,
                    updatedAt: entity.updatedAt
                )
            }
            await MainActor.run {
                self.addedAccounts = uiAccounts
                print("[Offline] Loaded \(uiAccounts.count) accounts from SwiftData.")
            }
            // Load emails for these accounts
            await self.loadEmailsFromSwiftDataOfflineFallback(userId: userId)
        } catch {
            print("[Offline] Error loading accounts from SwiftData: \(error.localizedDescription)")
            await MainActor.run { self.addedAccounts = [] }
        }
    }
    private func loadEmailsFromSwiftDataOfflineFallback(userId: UUID?) async {
        guard let context = modelContext else {
            print("ModelContext not available for SwiftData offline email load.")
            return
        }
        var emailsGrouped: [String: [EmailDisplayData]] = [:]
        let userAccounts: [EmailAccount]
        if let userId = userId {
            userAccounts = self.addedAccounts.filter { $0.userId == userId }
        } else {
            userAccounts = self.addedAccounts
        }
        for account in userAccounts {
            let accountEmail = account.emailAddress
            let descriptor = FetchDescriptor<EmailEntity>(predicate: #Predicate { $0.accountEmail == accountEmail }, sortBy: [SortDescriptor(\.date, order: .reverse)])
            do {
                let storedEmailEntities = try context.fetch(descriptor)
                let displayDatas = storedEmailEntities.map { entity -> EmailDisplayData in
                    EmailDisplayData(
                        gmailMessageId: entity.gmailMessageId,
                        threadId: entity.threadId,
                        messageIdHeader: entity.messageIdHeader,
                        referencesHeader: entity.referencesHeader,
                        sender: entity.sender,
                        senderEmail: entity.senderEmail,
                        recipient: entity.recipient,
                        subject: entity.subject,
                        snippet: entity.snippet,
                        body: entity.body,
                        date: entity.date,
                        isRead: entity.isRead,
                        previousMessages: nil,
                        accountEmail: entity.accountEmail,
                        labelIds: entity.labelIds
                    )
                }
                emailsGrouped[accountEmail] = displayDatas
                print("[Offline] Loaded \(displayDatas.count) emails from SwiftData for account \(accountEmail).")
            } catch {
                print("[Offline] Error loading emails from SwiftData for account \(accountEmail): \(error.localizedDescription)")
            }
        }
        await MainActor.run { self.emailsByAccount = emailsGrouped }
    }

    private func loadAccountsFromSupabase(for userId: UUID) async {
        print("Attempting to load accounts from Supabase for user: \(userId)")
        do {
            let loadedAccountsFromDB: [EmailAccount] = try await supabase
                .from("accounts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            await MainActor.run {
                self.addedAccounts = loadedAccountsFromDB
                print("Successfully loaded \(loadedAccountsFromDB.count) accounts from Supabase.")
            }

            if !loadedAccountsFromDB.isEmpty {
                // Save these to SwiftData
                await saveAccountsToSwiftData(accounts: loadedAccountsFromDB, for: userId)
                // Load related data from Supabase initially if not in SwiftData from a previous session
                await loadLabelsFromDatabase(for: userId) // This loads from Supabase & saves to SwiftData
                await loadEmailsFromDatabase(for: userId) // This loads from Supabase & saves to SwiftData
            } else {
                 await MainActor.run {
                     self.labelsByAccount = [:]
                     self.emailsByAccount = [:]
                 }
            }
            // Trigger API fetches which will also update SwiftData
            await triggerAPIFetchesForLoadedAccounts()

        } catch {
            print("Error loading accounts from Supabase: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to load saved accounts: \(error.localizedDescription)"
                self.addedAccounts = []
                self.labelsByAccount = [:]
                self.emailsByAccount = [:]
            }
        }
    }

    private func triggerAPIFetchesForLoadedAccounts() async {
        let accountsToFetch = await self.addedAccounts // Use the MainActor isolated version
        if accountsToFetch.isEmpty {
            print("No accounts to trigger API fetches for.")
            return
        }
        print("Triggering API fetches for labels and emails for loaded accounts...")
        for account in accountsToFetch {
            self.fetchLabels(for: account) // fetchLabels will handle its own Task/async and SwiftData saving
        }
        self.fetchAllInboxMessages() // fetchAllInboxMessages will handle its own Task/async and SwiftData saving
    }

    @MainActor
    private func saveAccountsToSwiftData(accounts: [EmailAccount], for userId: UUID) async {
        guard let context = modelContext else {
            print("ModelContext not available for saving accounts.")
            return
        }
        print("Saving \(accounts.count) accounts to SwiftData for user \(userId)...")
        for acc in accounts {
            // Check if account already exists to prevent duplicates based on emailAddress
            let email = acc.emailAddress
            let descriptor = FetchDescriptor<AccountEntity>(
                predicate: #Predicate { $0.emailAddress == email && $0.userId == userId }
            )
            
            do {
                if let existingAccount = try context.fetch(descriptor).first {
                    // Update existing account
                    existingAccount.provider = acc.provider
                    existingAccount.accountName = acc.accountName
                    existingAccount.lastSyncedAt = acc.lastSyncedAt ?? Date() // Update sync time
                    existingAccount.updatedAt = Date()
                    print("Updated existing account in SwiftData: \(email)")
                } else {
                    // Insert new account
                    let newAccountEntity = AccountEntity(
                        emailAddress: acc.emailAddress,
                        userId: userId, // Ensure userId is set
                        provider: acc.provider,
                        accountName: acc.accountName,
                        lastSyncedAt: acc.lastSyncedAt ?? Date(),
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    context.insert(newAccountEntity)
                    print("Inserted new account to SwiftData: \(email)")
                }
            } catch {
                print("Error checking/saving account \(email) to SwiftData: \(error.localizedDescription)")
            }
        }
        
        // Save the context changes
        do {
            try context.save()
            print("Successfully saved accounts context to SwiftData.")
        } catch {
            print("Error saving accounts context to SwiftData: \(error.localizedDescription)")
        }
    }
    
    // MARK: - SwiftData Loading and Saving Functions

    @MainActor
    private func saveEmailsToSwiftData(supabaseEmails: [SupabaseEmail], for userId: UUID) async {
        print("SwiftData DEBUG: Entered saveEmailsToSwiftData with \(supabaseEmails.count) emails")
        guard let context = modelContext else {
            print("ModelContext not available for saving emails to SwiftData.")
            return
        }
        print("Saving/Updating \(supabaseEmails.count) emails to SwiftData for user \(userId)...")

        for emailData in supabaseEmails {
            let providerMsgId = emailData.providerMessageId
            let accEmail = emailData.accountEmail
            
            let descriptor = FetchDescriptor<EmailEntity>(
                predicate: #Predicate { $0.gmailMessageId == providerMsgId && $0.accountEmail == accEmail }
            )
            
            do {
                if let existingEmail = try context.fetch(descriptor).first {
                    // Update existing email
                    existingEmail.threadId = emailData.threadId
                    existingEmail.messageIdHeader = emailData.messageIdHeader
                    existingEmail.referencesHeader = emailData.referencesHeader
                    existingEmail.sender = emailData.senderName ?? emailData.senderEmail ?? "Unknown Sender"
                    existingEmail.senderEmail = emailData.senderEmail
                    existingEmail.recipient = emailData.recipientTo
                    existingEmail.subject = emailData.subject ?? "No Subject"
                    existingEmail.snippet = emailData.snippet ?? ""
                    // Body is not in SupabaseEmail, so it won't be updated here unless fetched separately
                    existingEmail.date = emailData.dateReceived
                    existingEmail.isRead = emailData.isRead
                    existingEmail.labelIds = emailData.labelIds
                    // print("Updated email in SwiftData: \(existingEmail.subject) for \(accEmail)")
                } else {
                    // Insert new email
                    let newEmailEntity = EmailEntity(
                        gmailMessageId: emailData.providerMessageId,
                        threadId: emailData.threadId,
                        messageIdHeader: emailData.messageIdHeader,
                        referencesHeader: emailData.referencesHeader,
                        sender: emailData.senderName ?? emailData.senderEmail ?? "Unknown Sender",
                        senderEmail: emailData.senderEmail,
                        recipient: emailData.recipientTo,
                        subject: emailData.subject ?? "No Subject",
                        snippet: emailData.snippet ?? "",
                        body: "", // Body needs to be fetched separately and updated
                        date: emailData.dateReceived,
                        isRead: emailData.isRead,
                        accountEmail: emailData.accountEmail,
                        labelIds: emailData.labelIds
                    )
                    context.insert(newEmailEntity)
                    // print("Inserted new email to SwiftData: \(newEmailEntity.subject) for \(accEmail)")
                }
            } catch {
                print("Error checking/saving email \(providerMsgId) to SwiftData: \(error.localizedDescription)")
            }
        }
        
        do {
            try context.save()
            print("Successfully saved emails context to SwiftData.")
        } catch {
            print("Error saving emails context to SwiftData: \(error.localizedDescription)")
        }
    }

    // Note: Duplicate implementations of fetchLabels(for:), syncLabelsToDatabase(userId:accountEmail:labels:), 
    // and fetchAllInboxMessagesAsync() were removed from this section. 
    // The original implementations defined earlier in the file are being used instead.

    @MainActor
    private func loadLabelsFromSwiftData(for userId: UUID) async {
        guard let context = modelContext else {
            print("ModelContext not available for loading labels from SwiftData.")
            return
        }
        print("Attempting to load labels from SwiftData for user: \(userId)")
        
        let descriptor = FetchDescriptor<LabelEntity>(
            // We might need to fetch all labels and then group them by accountEmail,
            // or filter by specific account emails if we load them one by one.
            // For now, let's fetch all for the user and group.
            // predicate: #Predicate { $0.accountEmail == ??? } // Need account context here
        )
        
        do {
            let storedLabelEntities = try context.fetch(descriptor)
            var labelsGrouped: [String: [GTLRGmail_Label]] = [:]
            
            for labelEntity in storedLabelEntities {
                // Filter out labels not belonging to the current user's accounts if needed,
                // though ideally, data should be user-specific if userId was part of LabelEntity or fetched per account.
                // For now, assuming LabelEntity.accountEmail is sufficient if we filter UserViewModel.addedAccounts first.
                
                // Only process labels for accounts that are currently loaded for this user
                if self.addedAccounts.contains(where: { $0.emailAddress == labelEntity.accountEmail && $0.userId == userId }) {
                    let gtlrLabel = GTLRGmail_Label()
                    gtlrLabel.identifier = labelEntity.providerLabelId
                    gtlrLabel.name = labelEntity.name
                    gtlrLabel.type = labelEntity.type
                    labelsGrouped[labelEntity.accountEmail, default: []].append(gtlrLabel)
                }
            }
            
            // Only update if new data was actually loaded to avoid overwriting with empty if called prematurely
            if !labelsGrouped.isEmpty || storedLabelEntities.isEmpty { // If empty, means no data or we cleared it
                 self.labelsByAccount = labelsGrouped
            }
            print("Successfully loaded \(storedLabelEntities.count) labels from SwiftData and mapped to UI state for user \(userId).")

        } catch {
            print("Error loading labels from SwiftData: \(error.localizedDescription)")
            self.errorMessage = "Failed to load label cache from local: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadEmailsFromSwiftData(for userId: UUID) async {
        guard let context = modelContext else {
            print("ModelContext not available for loading emails from SwiftData.")
            return
        }
        print("Attempting to load emails from SwiftData for user: \(userId)")
        
        // Fetch all emails for the current user's accounts
        // We'll need to iterate through addedAccounts or fetch all and filter
        var emailsGrouped: [String: [EmailDisplayData]] = [:]
        let userAccounts = self.addedAccounts.filter { $0.userId == userId }

        for account in userAccounts {
            let accountEmail = account.emailAddress
            let descriptor = FetchDescriptor<EmailEntity>(
                predicate: #Predicate { $0.accountEmail == accountEmail },
                sortBy: [SortDescriptor(\.date, order: .reverse)] // Fix the key path syntax
            )
            
            do {
                let storedEmailEntities = try context.fetch(descriptor)
                let displayDatas = storedEmailEntities.map { entity -> EmailDisplayData in
                    // Map EmailEntity to EmailDisplayData
                    // Note: Body might be large. Consider if it should always be loaded or fetched on demand.
                    // For now, including it.
                    // `previousMessages` needs to be handled, likely by fetching other emails in the same threadId.
                    return EmailDisplayData(
                        gmailMessageId: entity.gmailMessageId,
                        threadId: entity.threadId,
                        messageIdHeader: entity.messageIdHeader,
                        referencesHeader: entity.referencesHeader,
                        sender: entity.sender,
                        senderEmail: entity.senderEmail,
                        recipient: entity.recipient,
                        subject: entity.subject,
                        snippet: entity.snippet,
                        body: entity.body, // Assuming body is stored and needed
                        date: entity.date,
                        isRead: entity.isRead,
                        previousMessages: nil, // TODO: Populate thread history if needed for display
                        accountEmail: entity.accountEmail,
                        labelIds: entity.labelIds
                    )
                }
                emailsGrouped[accountEmail] = displayDatas
                print("Loaded \(displayDatas.count) emails from SwiftData for account \(accountEmail).")
            } catch {
                print("Error loading emails from SwiftData for account \(accountEmail): \(error.localizedDescription)")
                // Continue to try loading for other accounts
            }
        }
        
        // Only update if new data was actually loaded
        if !emailsGrouped.isEmpty || userAccounts.isEmpty { // If userAccounts is empty, emailsByAccount should be empty
             self.emailsByAccount = emailsGrouped // Update UI state
        }
        print("Finished loading emails from SwiftData for user \(userId). Total accounts processed: \(userAccounts.count).")
    }
    // --- End SwiftData Loading Functions ---

    func clearUserSession() {
        print("Clearing user session data in UserViewModel.")
        userEmail = nil
        userName = nil
        addedAccounts = []
        emailsByAccount = [:]
        labelsByAccount = [:]
        nextPageTokens = [:]
        selectedAccountFilter = nil
        selectedLabelFilter = nil
        errorMessage = nil
        isLoading = false
        // Note: This does not clear SwiftData. If SwiftData should be cleared on logout,
        // that logic needs to be added here, considering multi-user data implications.
    }

    // MARK: - UserDefaults Keys
    private let lastUsedUserIdKey = "lastUsedUserId"
    private let lastUsedUserEmailKey = "lastUsedUserEmail"
}