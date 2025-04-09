import Foundation

// Enum to represent the optional metrics that can be tracked
enum OptionalHealthMetric: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case mood = "Mood"
    case sleep = "Sleep"
    case restingHR = "Resting HR"
    case hrv = "HRV"
    case waterIntake = "Water Intake"
    case stressLevel = "Stress Level"
    
    var id: String { self.rawValue }
    
    // Optional: Icon for the menu
    var iconName: String {
        switch self {
        case .weight: return "scalemass"
        case .mood: return "face.smiling"
        case .sleep: return "bed.double"
        case .restingHR: return "heart"
        case .hrv: return "waveform.path.ecg"
        case .waterIntake: return "drop"
        case .stressLevel: return "brain.head.profile"
        }
    }
} 