import Foundation

// Data Structures for Email Accounts and Folders

struct MailboxFolder: Identifiable {
    let id = UUID()
    let name: String
    let icon: String // SF Symbol name
    // Add other properties if needed, like folder ID from API
}

struct EmailAccount: Identifiable {
    let id = UUID() // Use email address as persistent ID?
    let emailAddress: String
    let provider: String // e.g., "gmail", "outlook"
    var folders: [MailboxFolder]? // Folders might be loaded later
    // Add placeholder for access token (retrieved via refresh token)
    // var currentAccessToken: String?
} 