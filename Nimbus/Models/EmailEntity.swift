import Foundation
import SwiftData

@Model
final class EmailEntity {
    @Attribute(.unique) var gmailMessageId: String // Actual ID from Gmail API
    var threadId: String? // Gmail thread ID
    var messageIdHeader: String? // Value of the Message-ID header
    var referencesHeader: String? // Value of the References header
    var sender: String // Name for Inbox view
    var senderEmail: String? // Full email for Detail view
    var recipient: String?
    var subject: String
    var snippet: String
    var body: String // Full email body
    var date: Date
    var isRead: Bool = false
    var accountEmail: String // To link with an AccountEntity
    var labelIds: [String]? // Store label IDs

    // Relationships
    // Consider if a direct link to AccountEntity is needed if accountEmail is already there
    // @Relationship(inverse: \AccountEntity.emails) var account: AccountEntity?
    
    // We'll store previous messages by fetching related messages by threadId if needed,
    // rather than a direct recursive relationship in SwiftData which can be complex.

    init(gmailMessageId: String, threadId: String? = nil, messageIdHeader: String? = nil, referencesHeader: String? = nil, sender: String, senderEmail: String? = nil, recipient: String? = nil, subject: String, snippet: String, body: String, date: Date, isRead: Bool = false, accountEmail: String, labelIds: [String]? = nil) {
        self.gmailMessageId = gmailMessageId
        self.threadId = threadId
        self.messageIdHeader = messageIdHeader
        self.referencesHeader = referencesHeader
        self.sender = sender
        self.senderEmail = senderEmail
        self.recipient = recipient
        self.subject = subject
        self.snippet = snippet
        self.body = body
        self.date = date
        self.isRead = isRead
        self.accountEmail = accountEmail
        self.labelIds = labelIds
    }
} 