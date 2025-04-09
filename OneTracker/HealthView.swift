import SwiftUI

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

// MARK: - Main Health View

struct HealthView: View {
    // Sample Health Data (replace with SwiftData/Persistence later)
    @State private var healthEntries: [HealthEntry] = [
        HealthEntry(date: Date().addingTimeInterval(-86400 * 2), weight: 185.5, mood: .good, sleepHours: 7.5, notes: "Feeling energetic.", restingHR: 58, hrv: 65, waterIntake: 80, stressLevel: .low),
        HealthEntry(date: Date().addingTimeInterval(-86400), weight: 185.2, mood: .okay, sleepHours: 6.0, notes: "A bit tired.", restingHR: 62, stressLevel: .medium),
        HealthEntry(date: Date(), mood: .veryGood, sleepHours: 8.5, waterIntake: 64)
    ]
    
    // State for presenting sheets
    @State private var showingAddEntry = false
    @State private var entryToEdit: HealthEntry? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Health")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    // Potential place for filters or summary views later
                }
                .padding([.horizontal, .top])
                
                // List of Health Entries
                List {
                    // Sectioning could be added later (e.g., by week/month)
                    ForEach(healthEntries.sorted(by: { $0.date > $1.date })) { entry in
                        // Row View (Placeholder - to be detailed later)
                        Button { // Action to set the entry to be edited
                            entryToEdit = entry
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.date, style: .date)
                                    // Display other details like weight, mood icon, sleep
                                    if let mood = entry.mood {
                                        HStack {
                                            Image(systemName: mood.icon)
                                                .foregroundStyle(mood.color)
                                            Text(mood.rawValue)
                                        }
                                        .font(.caption)
                                    }
                                    if let weight = entry.weight {
                                        Text("Weight: \(weight, specifier: "%.1f") lbs") // Add unit preference later
                                           .font(.caption)
                                    }
                                    // Display new optional data if present
                                    if let rhr = entry.restingHR {
                                        Text("RHR: \(rhr) bpm")
                                            .font(.caption)
                                    }
                                    if let hrv = entry.hrv {
                                        Text("HRV: \(hrv) ms")
                                            .font(.caption)
                                    }
                                    if let water = entry.waterIntake {
                                        Text("Water: \(water, specifier: "%.0f") fl oz")
                                            .font(.caption)
                                    }
                                    if let stress = entry.stressLevel {
                                        HStack {
                                            Circle().fill(stress.color).frame(width: 8, height: 8)
                                            Text("Stress: \(stress.rawValue)")
                                        }
                                        .font(.caption)
                                    }
                                    if let sleep = entry.sleepHours {
                                        Text("Sleep: \(sleep, specifier: "%.1f") hr")
                                           .font(.caption)
                                    }
                                    if let notes = entry.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            // Floating Action Button
            Button {
                showingAddEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.green) // Use a health-related color
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
            .padding()
            .padding(.bottom, 20)
            .padding(.trailing, 10)
        }
        // Sheet for Adding
        .sheet(isPresented: $showingAddEntry) {
            AddHealthEntryView(
                isPresented: $showingAddEntry,
                onSave: { newEntry in
                    healthEntries.append(newEntry)
                    // Consider sorting here if needed immediately
                }
            )
        }
        // Sheet for Editing
        .sheet(item: $entryToEdit) { entry in
            EditHealthEntryView(
                entry: entry,
                onUpdate: { updatedEntry in
                    // Find index and update
                    if let index = healthEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
                        healthEntries[index] = updatedEntry
                    }
                }
            )
        }
    }
}

#Preview {
    HealthView()
} 