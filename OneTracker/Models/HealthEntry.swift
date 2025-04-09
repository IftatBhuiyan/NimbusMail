import SwiftUI // Needed for Color
import Foundation // Needed for UUID, Date

// MARK: - Data Model for Health

struct HealthEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var weight: Double?       // in lbs or kg, user preference could be added later
    var mood: Mood?           // Optional mood tracking
    var sleepHours: Double?   // Optional sleep duration
    var notes: String?        // Optional general notes
    
    // New Optional Fields
    var restingHR: Int?       // Resting Heart Rate (BPM)
    var hrv: Int?             // Heart Rate Variability (ms)
    var waterIntake: Double?  // Water intake (e.g., fl oz)
    var stressLevel: StressLevel? // Optional stress level
    
    // Enum for Mood levels
    enum Mood: String, Codable, CaseIterable, Identifiable {
        case veryGood = "Very Good"
        case good = "Good"
        case okay = "Okay"
        case bad = "Bad"
        case veryBad = "Very Bad"
        
        var id: String { self.rawValue }
        
        // Example: Color representation for mood
        var color: Color {
            switch self {
            case .veryGood: return .green
            case .good: return .blue
            case .okay: return .yellow
            case .bad: return .orange
            case .veryBad: return .red
            }
        }
        
        // Example: SF Symbol for mood
        var icon: String {
            switch self {
            case .veryGood: return "face.smiling.fill"
            case .good: return "face.smiling"
            case .okay: return "face.neutral"
            case .bad: return "face.dashed"
            case .veryBad: return "face.dashed.fill" // Or another appropriate icon
            }
        }
    }
    
    // Enum for Stress Level
    enum StressLevel: String, Codable, CaseIterable, Identifiable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var id: String { self.rawValue }
        
        // Example: Color representation
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
} 