import Foundation

// Data Structures for Email Accounts and Folders

struct MailboxFolder: Identifiable {
    let id = UUID()
    let name: String
    let icon: String // SF Symbol name
    // Add other properties if needed, like folder ID from API
}

struct EmailAccount: Identifiable, Codable {
    let id: UUID // Make sure ID is Codable
    let emailAddress: String
    let provider: String // e.g., "gmail", "outlook"
    
    // Exclude folders from Codable as they are loaded dynamically
    var folders: [MailboxFolder]?
    
    // Define coding keys to exclude 'folders'
    enum CodingKeys: String, CodingKey {
        case id, emailAddress, provider
    }
    
    // Provide a default initializer if needed by Codable (especially if properties are let)
    // If all persisted properties are 'let', an implicit initializer might work,
    // but defining one explicitly is safer.
    init(id: UUID = UUID(), emailAddress: String, provider: String, folders: [MailboxFolder]? = nil) {
        self.id = id
        self.emailAddress = emailAddress
        self.provider = provider
        self.folders = folders
    }
    
    // We don't need custom encode/decode if we use CodingKeys
} 