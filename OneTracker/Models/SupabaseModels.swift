import Foundation

// MARK: - Supabase Database Models

/// Represents the structure of the 'labels' table in Supabase.
struct SupabaseLabel: Codable, Hashable {
    // Corresponds to DB columns
    var userId: UUID // user_id (FK)
    var accountEmail: String // account_email (FK)
    var providerLabelId: String // provider_label_id
    var name: String
    var type: String // e.g., 'system', 'user'
    var createdAt: Date? // created_at (set by DB default)
    var updatedAt: Date? // updated_at (set by DB default)

    // Map Swift property names to database column names
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accountEmail = "account_email"
        case providerLabelId = "provider_label_id"
        case name
        case type
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Need custom Hashable conformance because Date is not intrinsically Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
        hasher.combine(accountEmail)
        hasher.combine(providerLabelId)
    }

    static func == (lhs: SupabaseLabel, rhs: SupabaseLabel) -> Bool {
        lhs.userId == rhs.userId &&
        lhs.accountEmail == rhs.accountEmail &&
        lhs.providerLabelId == rhs.providerLabelId
    }
}

/// Represents the structure of the 'emails' table in Supabase.
struct SupabaseEmail: Codable, Hashable {
    var userId: UUID // user_id (FK)
    var accountEmail: String // account_email (FK)
    var providerMessageId: String // provider_message_id
    var threadId: String?
    var messageIdHeader: String?
    var referencesHeader: String?
    var senderName: String?
    var senderEmail: String?
    var recipientTo: String?
    var recipientCc: String?
    var recipientBcc: String?
    var subject: String?
    var snippet: String?
    // We might skip saving full bodies to DB initially to save space/complexity
    // var bodyHtml: String? 
    // var bodyPlain: String?
    var dateReceived: Date // date_received (use non-optional based on schema)
    var isRead: Bool
    var hasAttachments: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accountEmail = "account_email"
        case providerMessageId = "provider_message_id"
        case threadId = "thread_id"
        case messageIdHeader = "message_id_header"
        case referencesHeader = "references_header"
        case senderName = "sender_name"
        case senderEmail = "sender_email"
        case recipientTo = "recipient_to"
        case recipientCc = "recipient_cc"
        case recipientBcc = "recipient_bcc"
        case subject
        case snippet
        // case bodyHtml = "body_html"
        // case bodyPlain = "body_plain"
        case dateReceived = "date_received"
        case isRead = "is_read"
        case hasAttachments = "has_attachments"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Custom Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
        hasher.combine(accountEmail)
        hasher.combine(providerMessageId)
    }

    static func == (lhs: SupabaseEmail, rhs: SupabaseEmail) -> Bool {
        lhs.userId == rhs.userId &&
        lhs.accountEmail == rhs.accountEmail &&
        lhs.providerMessageId == rhs.providerMessageId
    }
}

/// Represents the structure of the 'email_labels' junction table in Supabase.
struct SupabaseEmailLabelLink: Codable, Hashable {
    var userId: UUID // user_id (FK)
    var accountEmail: String // account_email (FK)
    var providerMessageId: String // provider_message_id (FK)
    var providerLabelId: String // provider_label_id (FK)
    var assignedAt: Date? // assigned_at (set by DB default)

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accountEmail = "account_email"
        case providerMessageId = "provider_message_id"
        case providerLabelId = "provider_label_id"
        case assignedAt = "assigned_at"
    }
    
     // Custom Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
        hasher.combine(accountEmail)
        hasher.combine(providerMessageId)
        hasher.combine(providerLabelId)
    }

    static func == (lhs: SupabaseEmailLabelLink, rhs: SupabaseEmailLabelLink) -> Bool {
        lhs.userId == rhs.userId &&
        lhs.accountEmail == rhs.accountEmail &&
        lhs.providerMessageId == rhs.providerMessageId &&
        lhs.providerLabelId == rhs.providerLabelId
    }
}
