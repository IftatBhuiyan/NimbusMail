import Foundation

// Data Structures for Email Accounts and Folders

struct MailboxFolder: Identifiable {
    let id = UUID()
    let name: String
    let icon: String // SF Symbol name
    // Add other properties if needed, like folder ID from API
}

struct EmailAccount: Identifiable, Codable, Hashable {
    let id: UUID // Keep local UUID for Identifiable conformance in UI
    var userId: UUID? // FK to auth.users - Optional temporarily until fetched/set
    let emailAddress: String
    let provider: String // e.g., "gmail", "outlook"
    var accountName: String? // Optional display name
    var lastSyncedAt: Date? // Optional sync timestamp
    var createdAt: Date? // Optional creation timestamp (set by DB default)
    var updatedAt: Date? // Optional update timestamp (set by DB default)
    
    // Exclude folders from Codable as they are loaded dynamically
    // var folders: [MailboxFolder]? // Commenting out as it's not persisted
    
    // Define coding keys to map to DB columns
    enum CodingKeys: String, CodingKey {
        // Map Swift property names to database column names
        // Remove 'id' as it's not a database column
        // case id 
        case userId = "user_id"
        case emailAddress = "email_address"
        case provider
        case accountName = "account_name"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Explicit initializer for creating instances in code
    init(id: UUID = UUID(), userId: UUID? = nil, emailAddress: String, provider: String, accountName: String? = nil, lastSyncedAt: Date? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.emailAddress = emailAddress
        self.provider = provider
        self.accountName = accountName
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom Decodable initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode all properties defined in CodingKeys
        self.userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        self.emailAddress = try container.decode(String.self, forKey: .emailAddress)
        self.provider = try container.decode(String.self, forKey: .provider)
        self.accountName = try container.decodeIfPresent(String.self, forKey: .accountName)
        self.lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        // Manually assign a new UUID for the local 'id' property
        self.id = UUID()
    }
    
    // Add Hashable conformance (based on unique elements for an account)
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId) // Use userId if available
        hasher.combine(emailAddress)
    }
    
    static func == (lhs: EmailAccount, rhs: EmailAccount) -> Bool {
        lhs.userId == rhs.userId && lhs.emailAddress == rhs.emailAddress
    }
} 