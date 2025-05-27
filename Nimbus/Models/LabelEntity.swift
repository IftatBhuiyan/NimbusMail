import Foundation
import SwiftData

@Model
final class LabelEntity {
    @Attribute(.unique) var providerLabelId: String // Unique ID from the email provider (e.g., Gmail label ID)
    var accountEmail: String // Which account this label belongs to
    var name: String // Display name of the label (e.g., "Inbox", "Work")
    var type: String? // Type of label (e.g., "system", "user")

    init(providerLabelId: String, accountEmail: String, name: String, type: String? = nil) {
        self.providerLabelId = providerLabelId
        self.accountEmail = accountEmail
        self.name = name
        self.type = type
    }
} 