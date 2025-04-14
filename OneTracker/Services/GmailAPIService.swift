import Foundation
import GoogleAPIClientForREST_Gmail
import GoogleSignIn
import GTMSessionFetcherCore
// Service to interact with the Gmail API

@MainActor // Use MainActor if updates trigger UI changes directly
class GmailAPIService {
    
    static let shared = GmailAPIService()
    private let service = GTLRGmailService()
    
    private init() {
        // Basic configuration
        // Disable automatic page fetching
        service.shouldFetchNextPages = false 
        service.isRetryEnabled = true
    }
    
    // MARK: - Fetching Labels (Folders)
    
    func fetchLabels(for account: EmailAccount, completion: @escaping (Result<[MailboxFolder], Error>) -> Void) {
        print("Attempting to fetch labels for \(account.emailAddress)")
        
        // 1. Get Authorizer (Use GTMSessionFetcherAuthorizer type)
        getAuthorizer(for: account.emailAddress) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let authorizer):
                // Set the authorizer for the API service
                self.service.authorizer = authorizer // GTLRService should accept this type
                
                // 2. Prepare the API Query
                // Fetch system labels (INBOX, SENT, etc.) and user-created labels
                let query = GTLRGmailQuery_UsersLabelsList.query(withUserId: "me")
                
                // 3. Execute the Query
                self.service.executeQuery(query) { (ticket, response, error) in
                    if let error = error {
                        print("Error fetching labels: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let listResponse = response as? GTLRGmail_ListLabelsResponse, 
                          let labels = listResponse.labels else {
                        print("Error: Could not parse label response or no labels found.")
                        completion(.failure(NSError(domain: "GmailAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid label response"])))
                        return
                    }
                    
                    // 4. Map GTLR Labels to MailboxFolder
                    let mailboxFolders = labels.compactMap { gtlrLabel -> MailboxFolder? in
                        guard let name = gtlrLabel.name else { return nil }
                        // Map common system labels to specific icons, default for others
                        let icon: String
                        switch gtlrLabel.identifier?.uppercased() { // Use ID for system labels
                            case "INBOX": icon = "tray.fill"
                            case "SENT": icon = "paperplane.fill"
                            case "DRAFT": icon = "doc.fill"
                            case "SPAM": icon = "xmark.bin.fill"
                            case "TRASH": icon = "trash.fill"
                            case "IMPORTANT": icon = "exclamationmark.circle.fill"
                            case "STARRED": icon = "star.fill"
                            default: icon = "folder.fill" // Default icon for user labels
                        }
                        return MailboxFolder(name: name, icon: icon)
                    }
                    
                    print("Successfully fetched \(mailboxFolders.count) labels.")
                    completion(.success(mailboxFolders))
                }
                
            case .failure(let error):
                print("Failed to get authorizer: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Authentication Helper (Placeholder)
    
    // This is the complex part. It needs to securely retrieve the refresh token
    // and use it to obtain a fresh access token.
    // Libraries like GTMAppAuth can simplify this significantly.
    // Update signature and completion handler to use GTMSessionFetcherAuthorizer
    private func getAuthorizer(for userEmail: String, completion: @escaping (Result<GTMSessionFetcherAuthorizer, Error>) -> Void) {
        // 1. Load Refresh Token from Keychain
        guard let refreshToken = KeychainService.loadToken(account: userEmail) else {
            print("Error: Could not load refresh token for \(userEmail) from Keychain.")
            completion(.failure(NSError(domain: "GmailAPIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing refresh token"])))
            return
        }
        // Acknowledge refreshToken to silence warning (it's used via Keychain implicitly)
        _ = refreshToken
        
        // 2. TODO: Implement Token Refresh Logic
        //    - This typically involves an HTTPS POST request to Google's token endpoint
        //      (https://oauth2.googleapis.com/token) with:
        //        - client_id: Your app's client ID
        //        - client_secret: *If applicable* (for server-side apps, usually NOT for iOS)
        //        - refresh_token: The token loaded from Keychain
        //        - grant_type: "refresh_token"
        //    - Parse the response to get the new access_token and its expiry time.
        
        // 3. TODO: Create Authorizer Object
        //    - Once you have a valid access_token, create an authorizer object.
        //    - If using GTMAppAuth, it manages this process for you.
        //    - If doing manually, you might use GTMSessionFetcherAuthorizer or similar.
        
        // --- Placeholder --- 
        print("Placeholder: Token refresh logic needed in getAuthorizer.")
        // For now, try using GIDSignIn's currentUser for a potentially valid (but maybe expired) authorizer
        // THIS IS NOT RELIABLE FOR BACKGROUND FETCHING - ONLY FOR IMMEDIATE POST-SIGN-IN CALLS
        
        // Check if currentUser exists, then directly access fetcherAuthorizer (it's not optional)
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            // Cast the non-optional protocol to the required class type
            if let authorizer = currentUser.fetcherAuthorizer as? GTMSessionFetcherAuthorizer {
                 print("Using authorizer from GIDSignIn.sharedInstance.currentUser (may be expired)")
                 completion(.success(authorizer))
             } else {
                 // This case is unlikely if fetcherAuthorizer exists but might happen if types change
                 print("Error: Could not cast fetcherAuthorizer to GTMSessionFetcherAuthorizer.")
                 completion(.failure(NSError(domain: "GmailAPIService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Authorizer type mismatch"])))
             }
        } else {
            print("Error: No Google user signed in. Need token refresh logic or sign-in.")
            completion(.failure(NSError(domain: "GmailAPIService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Authorization failed - No user signed in"])))
        }
        // --- End Placeholder --- 
    }
    
    // MARK: - Fetching Messages (Manual Pagination)
    
    // Fetches inbox message IDs, handling pagination manually, up to a specified limit.
    func fetchInboxMessages(for account: EmailAccount, maxTotalMessages: Int = 100, completion: @escaping (Result<[GTLRGmail_Message], Error>) -> Void) {
        print("Attempting to fetch up to \(maxTotalMessages) inbox messages for \(account.emailAddress) with manual pagination")
        
        var allMessages: [GTLRGmail_Message] = []
        var currentPageToken: String? = nil
        let maxResultsPerPage: UInt = 500 // Use API max

        // Recursive helper function to fetch pages
        func fetchPage(authorizer: GTMSessionFetcherAuthorizer) {
            let query = GTLRGmailQuery_UsersMessagesList.query(withUserId: "me")
            query.labelIds = ["INBOX"]
            query.maxResults = maxResultsPerPage
            query.pageToken = currentPageToken // Set page token if available
            
            self.service.authorizer = authorizer // Ensure authorizer is set for each call

            print("Fetching page with token: \(currentPageToken ?? "nil")")

            self.service.executeQuery(query) { (ticket, response, error) in
                if let error = error {
                    print("Error fetching message page: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let listResponse = response as? GTLRGmail_ListMessagesResponse else {
                    print("Error: Could not parse message list response.")
                    completion(.failure(NSError(domain: "GmailAPIService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid message list response"])))
                    return
                }

                // Append messages from the current page
                if let messages = listResponse.messages {
                    allMessages.append(contentsOf: messages)
                    print("Fetched \(messages.count) message IDs on this page. Total collected: \(allMessages.count)")
                } else {
                     print("No messages on this page.")
                }

                // Check for the next page token AND if we've reached the desired limit
                if let nextToken = listResponse.nextPageToken, !nextToken.isEmpty, allMessages.count < maxTotalMessages {
                    currentPageToken = nextToken
                    // Fetch the next page recursively
                    fetchPage(authorizer: authorizer) 
                } else {
                    // No more pages, reached limit, or error - complete successfully
                    print("Finished fetching pages (or reached limit of \(maxTotalMessages)). Total message IDs collected: \(allMessages.count)")
                    // Return only up to the maxTotalMessages requested
                    completion(.success(Array(allMessages.prefix(maxTotalMessages))))
                }
            }
        }

        // Start the process by getting the authorizer
        getAuthorizer(for: account.emailAddress) { [weak self] result in
            guard self != nil else { return }
            
            switch result {
            case .success(let authorizer):
                // Start fetching the first page
                fetchPage(authorizer: authorizer)
            case .failure(let error):
                print("Failed to get authorizer for fetching messages: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetching Message Details

    func fetchMessageDetails(for account: EmailAccount, messageId: String, completion: @escaping (Result<GTLRGmail_Message, Error>) -> Void) {
        print("Attempting to fetch details for message ID: \(messageId) for account \(account.emailAddress)")
        
        getAuthorizer(for: account.emailAddress) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let authorizer):
                self.service.authorizer = authorizer
                
                // Query to get specific metadata fields
                let query = GTLRGmailQuery_UsersMessagesGet.query(withUserId: "me", identifier: messageId)
                query.format = "metadata" // Fetch metadata only (headers, snippet)
                query.metadataHeaders = ["Subject", "From", "Date", "To", "Cc", "Bcc"] // Specify needed headers
                
                self.service.executeQuery(query) { (ticket, response, error) in
                    if let error = error {
                        print("Error fetching details for message \(messageId): \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let message = response as? GTLRGmail_Message else {
                        print("Error: Could not parse message details response for \(messageId).")
                        completion(.failure(NSError(domain: "GmailAPIService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid message details response"])))
                        return
                    }
                    
                    print("Successfully fetched details for message ID: \(messageId)")
                    completion(.success(message))
                }
                
            case .failure(let error):
                print("Failed to get authorizer for fetching message details: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetching Full Message Content

    func fetchFullMessage(for account: EmailAccount, messageId: String, completion: @escaping (Result<GTLRGmail_Message, Error>) -> Void) {
        print("Attempting to fetch FULL details for message ID: \(messageId) for account \(account.emailAddress)")
        
        getAuthorizer(for: account.emailAddress) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let authorizer):
                self.service.authorizer = authorizer
                
                let query = GTLRGmailQuery_UsersMessagesGet.query(withUserId: "me", identifier: messageId)
                query.format = "full" // Fetch the full payload, including body parts
                
                self.service.executeQuery(query) { (ticket, response, error) in
                    if let error = error {
                        print("Error fetching full details for message \(messageId): \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let message = response as? GTLRGmail_Message else {
                        print("Error: Could not parse full message details response for \(messageId).")
                        completion(.failure(NSError(domain: "GmailAPIService", code: -7, userInfo: [NSLocalizedDescriptionKey: "Invalid full message details response"])))
                        return
                    }
                    
                    print("Successfully fetched FULL details for message ID: \(messageId)")
                    completion(.success(message))
                }
                
            case .failure(let error):
                print("Failed to get authorizer for fetching full message details: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Helper for Body Extraction
    // Extracts HTML body from a message payload, falling back to plain text.
    static func extractBestBody(from message: GTLRGmail_Message) -> String? {
        guard let payload = message.payload else { return nil }
        // Prioritize HTML
        if let htmlBody = findBody(in: payload, mimeType: "text/html") {
            return htmlBody
        }
        // Fallback to plain text
        if let plainBody = findBody(in: payload, mimeType: "text/plain") {
            return plainBody
        }
        // No suitable body found
        return nil
    }

    // Recursive helper to find body content for a specific MIME type
    private static func findBody(in payload: GTLRGmail_MessagePart, mimeType: String) -> String? {
        // Check current part
        if payload.mimeType == mimeType,
           let bodyData = payload.body?.data,
           let decodedData = Data(base64URLEncoded: bodyData),
           let bodyString = String(data: decodedData, encoding: .utf8) {
            return bodyString
        }

        // If multipart, recursively search parts
        if let parts = payload.parts, payload.mimeType?.starts(with: "multipart/") == true {
            for part in parts {
                if let foundBody = findBody(in: part, mimeType: mimeType) {
                    return foundBody // Return the first match of the desired type
                }
            }
        }

        // MIME type not found in this part or its children
        return nil
    }
    
    // MARK: - Other API Methods (Placeholders)
    // func fetchMessageDetails(messageId: String, account: EmailAccount, ...) -> GTLRGmail_Message { ... } // Keep this for list view
}

// Helper extension for Base64 URL Decoding (common need with Gmail API)
extension Data {
    init?(base64URLEncoded input: String) {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Add padding if necessary
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        self.init(base64Encoded: base64)
    }
} 
