import SwiftUI // Needed for Color
import Foundation // Needed for UUID, Date

// Model for fitness activities
struct FitnessActivity: Identifiable, Codable {
    var id = UUID()
    var type: String      // e.g., "Running", "Cycling", "Weights"
    var duration: Int     // in minutes
    var calories: Int     // estimated calories burned
    var date: Date
    var notes: String?
    
    // For workout intensity
    var intensity: Intensity
    
    // Type-specific optional details
    var distance: Double?     // in miles (or yards for swimming)
    var sets: Int?           // for weight training
    var reps: Int?           // for weight training
    var weight: Double?      // for weight training (in lbs)
    var pace: Double?        // for running/walking (min/mile)
    var laps: Int?           // for swimming
    var elevationGain: Double? // for cycling/hiking (in feet)
    var heartRate: Int?      // average heart rate (bpm)
    var steps: Int?          // for walking (count)
    var route: String?       // route description
    var style: String?       // yoga style, swimming stroke, etc.
    
    enum Intensity: String, Codable, CaseIterable {
        case light = "Light"
        case moderate = "Moderate"
        case intense = "Intense"
        
        // Computed properties for display
        var flameCount: Int {
            switch self {
            case .light: return 1
            case .moderate: return 2
            case .intense: return 3
            }
        }
        
        var iconColor: Color {
            switch self {
            case .light: return .green
            case .moderate: return .orange
            case .intense: return .red
            }
        }
    }
} 