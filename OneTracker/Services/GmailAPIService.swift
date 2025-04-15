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
    
    // MARK: - Fetching Threads (Replaces fetchInboxMessages)

    // Fetches inbox thread IDs and details, handling pagination.
    // Updated to accept optional labelIds and searchQuery
    // Updated completion handler to return nextPageToken
    func fetchInboxThreads(for account: EmailAccount, labelIds: [String]? = nil, searchQuery: String? = nil, pageToken: String? = nil, maxTotalThreads: Int = 50, completion: @escaping (Result<([GTLRGmail_Thread], String?), Error>) -> Void) {
        print("Attempting to fetch threads for \(account.emailAddress). Labels: \(labelIds?.joined(separator: ", ") ?? "N/A"), Query: \(searchQuery ?? "N/A"), PageToken: \(pageToken ?? "nil"), Limit: \(maxTotalThreads)")
        
        // -- Simplified Fetch Logic (Fetch ONE Page) ---
        getAuthorizer(for: account.emailAddress) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let authorizer):
                self.service.authorizer = authorizer
                let listQuery = GTLRGmailQuery_UsersThreadsList.query(withUserId: "me")
                
                // Use labelIds or searchQuery conditionally
                if let labelIds = labelIds, !labelIds.isEmpty {
                    listQuery.labelIds = labelIds
                }
                if let searchQuery = searchQuery, !searchQuery.isEmpty {
                    listQuery.q = searchQuery
                }
                // Use the provided pageToken
                listQuery.pageToken = pageToken 
                // Limit results per page (adjust as needed, 50 is reasonable)
                listQuery.maxResults = UInt(min(maxTotalThreads, 50)) 

                self.service.executeQuery(listQuery) { [weak self] (ticket, response, error) in
                    guard let self = self else { return }

                    if let error = error {
                        print("Error fetching thread list page: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }

                    guard let listResponse = response as? GTLRGmail_ListThreadsResponse else {
                        print("Error: Could not parse thread list response.")
                        completion(.failure(NSError(domain: "GmailAPIService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Invalid thread list response"])))
                        return
                    }

                    let threadInfos = listResponse.threads ?? []
                    let nextPageToken = listResponse.nextPageToken // Capture the next page token
                    print("Fetched \(threadInfos.count) thread infos. Next page token: \(nextPageToken ?? "nil")")
                    
                    // Fetch full details for this page's threads
                    self.fetchFullThreads(for: account, threadInfos: threadInfos, authorizer: authorizer) { result in
                        switch result {
                        case .success(let fetchedThreads):
                            print("Fetched details for \(fetchedThreads.count) threads.")
                            // Complete with threads for THIS page and the next token
                            completion(.success((fetchedThreads, nextPageToken))) 
                        case .failure(let detailError):
                            print("Error fetching full thread details: \(detailError.localizedDescription)")
                            completion(.failure(detailError))
                        }
                    }
                }
                
            case .failure(let error):
                print("Failed to get authorizer for fetching threads: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // Helper to fetch full details for multiple threads concurrently
    private func fetchFullThreads(for account: EmailAccount, threadInfos: [GTLRGmail_Thread], authorizer: GTMSessionFetcherAuthorizer, completion: @escaping (Result<[GTLRGmail_Thread], Error>) -> Void) {
        guard !threadInfos.isEmpty else {
            completion(.success([]))
            return
        }
        
        var fetchedThreads: [GTLRGmail_Thread] = []
        let group = DispatchGroup()
        var firstError: Error? = nil

        for info in threadInfos {
            guard let threadId = info.identifier else { continue }
            group.enter()
            
            // Use the existing authorizer
            self.service.authorizer = authorizer 
            
            let query = GTLRGmailQuery_UsersThreadsGet.query(withUserId: "me", identifier: threadId)
            // Request headers needed for mapping and replying
            query.format = "metadata"
            query.metadataHeaders = ["Subject", "From", "Date", "To", "Cc", "Bcc", "Message-ID", "References"]
            
            self.service.executeQuery(query) { (ticket, response, error) in
                if let error = error {
                    print("Error fetching details for thread \(threadId): \(error.localizedDescription)")
                    // Store the first error encountered
                    if firstError == nil { firstError = error }
                } else if let thread = response as? GTLRGmail_Thread {
                     // Check if thread actually contains messages before adding
                     if let messages = thread.messages, !messages.isEmpty {
                         fetchedThreads.append(thread)
                     } else {
                         print("Thread \(threadId) fetched but contained no messages (or messages couldn't be parsed), skipping.")
                     }
                } else {
                    print("Error: Could not parse thread details response for \(threadId).")
                    if firstError == nil {
                         firstError = NSError(domain: "GmailAPIService", code: -11, userInfo: [NSLocalizedDescriptionKey: "Invalid thread details response for \(threadId)"])
                     }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let error = firstError {
                completion(.failure(error))
            } else {
                completion(.success(fetchedThreads))
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
                query.metadataHeaders = ["Subject", "From", "Date", "To", "Cc", "Bcc", "Message-ID", "References"] // Specify needed headers, including Message-ID and References
                
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

    // MARK: - Helper for Body Extraction (Revised)
    // Extracts the best possible body content (HTML preferred) from a message payload,
    // attempting to separate the reply from the quoted text.
    static func extractBestBodyParts(from message: GTLRGmail_Message) -> (reply: String?, quote: String?) {
        guard let payload = message.payload else { return (nil, nil) }
        
        let rawBody = findBestBodyRecursive(in: payload)
        guard let bodyString = rawBody else { return (nil, nil) }
        
        return parseBodyStringForReplyAndQuote(bodyString)
    }
    
    // Updated helper to parse a body string (HTML or plain) into reply and quote
    static func parseBodyStringForReplyAndQuote(_ bodyString: String) -> (reply: String?, quote: String?) {
        // --- HTML Parsing Attempt --- 
        // Look for the standard blockquote used by Gmail for replies
        if let quoteRange = bodyString.range(of: "<blockquote type=\"cite\"", options: [.caseInsensitive]) {
            let replyPart = String(bodyString[..<quoteRange.lowerBound])
            let quotePart = String(bodyString[quoteRange.lowerBound...])
            let cleanedReply = replyPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedReply.isEmpty ? (bodyString, nil) : (cleanedReply, quotePart)
        }
        // Fallback check for the older gmail_quote div (just in case)
        if let quoteRange = bodyString.range(of: "<div class=\"gmail_quote\">", options: [.caseInsensitive]) {
            let replyPart = String(bodyString[..<quoteRange.lowerBound])
            let quotePart = String(bodyString[quoteRange.lowerBound...])
            let cleanedReply = replyPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedReply.isEmpty ? (bodyString, nil) : (cleanedReply, quotePart)
        }
        
        // --- Plain Text Parsing Attempt (or if HTML parsing failed) ---
        // Check for "On ... wrote:" pattern
        // More robust regex might be needed for different languages/formats
        let onDatewroteRegex = try? NSRegularExpression(pattern: "^On .* wrote:\\s*$", options: [.anchorsMatchLines, .caseInsensitive])
        if let match = onDatewroteRegex?.firstMatch(in: bodyString, options: [], range: NSRange(bodyString.startIndex..., in: bodyString)) {
            let quoteStartIndex = bodyString.index(bodyString.startIndex, offsetBy: match.range.location)
            let replyPart = String(bodyString[..<quoteStartIndex])
            let quotePart = String(bodyString[quoteStartIndex...])
            let cleanedReply = replyPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedReply.isEmpty ? (bodyString, nil) : (cleanedReply, quotePart)
        }
        
        // Check for lines starting with > (common plain text quoting)
        if let firstQuoteLineRange = bodyString.range(of: "\n>", options: []) {
            let replyPart = String(bodyString[..<firstQuoteLineRange.lowerBound])
            let quotePart = String(bodyString[firstQuoteLineRange.lowerBound...]) // Keep the newline
             let cleanedReply = replyPart.trimmingCharacters(in: .whitespacesAndNewlines)
             // Return parts only if reply is non-empty, otherwise treat whole as reply
             return cleanedReply.isEmpty ? (bodyString, nil) : (cleanedReply, quotePart)
        } else if bodyString.starts(with: ">") {
             // Handle case where the very first line is quoted
             return (nil, bodyString)
        }

        // --- Fallback --- 
        // If no quote indicators found, assume the whole thing is the reply
        return (bodyString, nil)
    }

    // Recursive helper to find the best body content for display.
    // Prioritizes HTML within multipart/alternative, then searches recursively.
    private static func findBestBodyRecursive(in payload: GTLRGmail_MessagePart) -> String? {
        let mimeType = payload.mimeType?.lowercased() ?? ""
        
        // 1. Handle multipart/alternative: Look for HTML first, then plain text
        if mimeType == "multipart/alternative", let parts = payload.parts {
            // Prefer HTML
            for part in parts {
                if part.mimeType?.lowercased() == "text/html" {
                    if let htmlBody = decodeBody(from: part) {
                        return htmlBody
                    }
                }
            }
            // Fallback to Plain Text
            for part in parts {
                 if part.mimeType?.lowercased() == "text/plain" {
                    if let plainBody = decodeBody(from: part) {
                         // Optionally wrap plain text in <pre> for basic formatting
                         return "<pre>\(plainBody)</pre>"
                    }
                }
            }
        }
        
        // 2. Handle other multipart types: Recurse into parts
        //    (e.g., multipart/related, multipart/mixed)
        if mimeType.starts(with: "multipart/"), let parts = payload.parts {
            for part in parts {
                // Only recurse into sub-multiparts or text parts
                // We are looking for the *main* displayable body here, not traversing attachments yet.
                 if part.mimeType?.lowercased().starts(with: "multipart/") == true ||
                    part.mimeType?.lowercased().starts(with: "text/") == true {
                    if let foundBody = findBestBodyRecursive(in: part) {
                        return foundBody // Return the first suitable body found in sub-parts
                    }
                }
            }
        }
        
        // 3. Handle single text/html part
        if mimeType == "text/html" {
            if let htmlBody = decodeBody(from: payload) {
                return htmlBody
            }
        }
        
        // 4. Handle single text/plain part (as fallback if no HTML found)
        if mimeType == "text/plain" {
            if let plainBody = decodeBody(from: payload) {
                 // Optionally wrap plain text in <pre> for basic formatting
                 return "<pre>\(plainBody)</pre>"
            }
        }
        
        // 5. No suitable body found in this part or its children
        return nil
    }

    // Helper to decode Base64URL encoded body data from a part
    private static func decodeBody(from part: GTLRGmail_MessagePart) -> String? {
         guard let bodyData = part.body?.data,
               let decodedData = Data(base64URLEncoded: bodyData),
               let bodyString = String(data: decodedData, encoding: .utf8) else {
             // Try decoding filename if body data is nil (some clients might do this)
             // This is less common but worth a try as a fallback
             if let filename = part.filename, !filename.isEmpty, 
                let decodedFilename = Data(base64URLEncoded: filename), // Check if filename itself is encoded
                let filenameString = String(data: decodedFilename, encoding: .utf8) {
                 print("Warning: Decoding body from filename for part with MIME type \(part.mimeType ?? "unknown")")
                 return filenameString
             }
             return nil // Truly couldn't decode
         }
         return bodyString
    }
    
    // MARK: - Other API Methods (Placeholders)
    // func fetchMessageDetails(messageId: String, account: EmailAccount, ...) -> GTLRGmail_Message { ... } // Keep this for list view
    
    // MARK: - Send Email
    
    func sendEmail(for account: EmailAccount, to: String, cc: String?, bcc: String?, subject: String, body: String, originalEmail: EmailDisplayData? = nil, completion: @escaping (Result<GTLRGmail_Message, Error>) -> Void) {
        // Use the completion handler pattern for getAuthorizer
        getAuthorizer(for: account.emailAddress) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let authorizer):
                self.service.authorizer = authorizer
                
                let message = GTLRGmail_Message()
                
                // If replying, set the thread ID
                if let original = originalEmail, let threadId = original.threadId {
                    message.threadId = threadId
                }
                
                // Construct the raw email string (RFC 822 format)
                // Generate a unique Message-ID for this new message
                let newMessageId = "<\(UUID().uuidString)@\(account.emailAddress.split(separator: "@").last ?? "local.host")>"
                
                var emailString = "From: \(account.emailAddress)\r\n"
                emailString += "To: \(to)\r\n"
                if let cc = cc, !cc.isEmpty {
                    emailString += "Cc: \(cc)\r\n"
                }
                if let bcc = bcc, !bcc.isEmpty {
                    emailString += "Bcc: \(bcc)\r\n" 
                }
                emailString += "Subject: \(subject)\r\n"
                emailString += "Message-ID: \(newMessageId)\r\n"
                
                // Add reply headers if applicable
                if let original = originalEmail, let originalMessageIdHeader = original.messageIdHeader {
                    emailString += "In-Reply-To: \(originalMessageIdHeader)\r\n"
                    // Construct References header: append original Message-ID to existing References (if any)
                    var references = original.referencesHeader ?? "" // Start with previous references
                    if !references.isEmpty {
                        references += " " // Add space separator
                    }
                    references += originalMessageIdHeader // Append the ID being replied to
                    emailString += "References: \(references)\r\n"
                }
                
                emailString += "Content-Type: text/plain; charset=utf-8\r\n"
                emailString += "Content-Transfer-Encoding: 7bit\r\n\r\n"
                emailString += body
                
                // Base64 URL encode the string
                guard let emailData = emailString.data(using: .utf8) else {
                     completion(.failure(NSError(domain: "GmailAPIService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode email content."])))
                    return
                }
                message.raw = emailData.base64EncodedString(options: .endLineWithCarriageReturn)
                                        .replacingOccurrences(of: "+", with: "-")
                                        .replacingOccurrences(of: "/", with: "_")
                                        .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        
                // Add uploadParameters: nil to the query call
                let query = GTLRGmailQuery_UsersMessagesSend.query(withObject: message, userId: "me", uploadParameters: nil)
                
                print("Sending email... To: \(to), Subject: \(subject)")
                self.service.executeQuery(query) { (ticket, sentMessage, error) in
                    if let error = error {
                        print("Error sending email: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else if let sentMessage = sentMessage as? GTLRGmail_Message {
                        print("Email sent successfully. ID: \(sentMessage.identifier ?? "N/A")")
                        completion(.success(sentMessage))
                    } else {
                        print("Error sending email: Unknown error, no message object returned.")
                        completion(.failure(NSError(domain: "GmailAPIService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unknown error sending email."])))
                    }
                }
                
            case .failure(let error):
                print("Failed to get authorizer for sending email: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Fetching Labels

    func fetchLabels(for account: EmailAccount, completion: @escaping (Result<[GTLRGmail_Label], Error>) -> Void) {
        print("Attempting to fetch labels for \(account.emailAddress)")
        
        // 1. Get Authorizer
        getAuthorizer(for: account.emailAddress) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let authorizer):
                self.service.authorizer = authorizer
                
                // 2. Prepare the API Query
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
                    
                    print("Successfully fetched \(labels.count) labels for \(account.emailAddress).")
                    completion(.success(labels))
                }
                
            case .failure(let error):
                print("Failed to get authorizer for fetching labels: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
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
