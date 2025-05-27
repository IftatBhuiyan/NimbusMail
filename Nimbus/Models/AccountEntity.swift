import Foundation
import SwiftData

@Model
final class AccountEntity {
    @Attribute(.unique) var emailAddress: String // Unique identifier for the account
    var userId: UUID? // FK to auth.users
    var provider: String // e.g., "gmail", "outlook"
    var accountName: String?
    var lastSyncedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    // Relationship to emails (one-to-many)
    // SwiftData will automatically manage the inverse relationship if specified in EmailEntity
    // For simplicity, we might fetch emails based on accountEmail query in EmailEntity
    // @Relationship(deleteRule: .cascade) var emails: [EmailEntity]?

    init(emailAddress: String, userId: UUID? = nil, provider: String, accountName: String? = nil, lastSyncedAt: Date? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.emailAddress = emailAddress
        self.userId = userId
        self.provider = provider
        self.accountName = accountName
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 