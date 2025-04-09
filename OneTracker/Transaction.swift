import Foundation
import SwiftData

// Define the frequency options
enum Frequency: String, Codable, CaseIterable { // Codable for SwiftData, CaseIterable for Picker
    case oneTime = "One-Time"
    case recurring = "Recurring"
}

@Model
final class Transaction {
    var merchant: String
    var bank: String
    var amount: Double
    var date: Date // For one-time, the transaction date; for recurring, the start date
    var frequency: Frequency = Frequency.oneTime // Explicitly use Frequency.oneTime
    var recurringEndDate: Date? = nil // Optional end date for recurring transactions

    init(merchant: String = "", bank: String = "", amount: Double = 0.0, date: Date = Date(), frequency: Frequency = Frequency.oneTime, recurringEndDate: Date? = nil) { // Also explicit here
        self.merchant = merchant
        self.bank = bank
        self.amount = amount
        self.date = date
        self.frequency = frequency
        self.recurringEndDate = recurringEndDate
    }
} 