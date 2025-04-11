import SwiftUI

// Removed HealthEntry struct definition (moved to Models/HealthEntry.swift)

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

    // Date formatter for entry display
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long // e.g., April 11, 2025
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Neumorphic background
            neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)

            // Main Content Container with Inner Shadow
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Health")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic Text Color
                    Spacer()
                    // Potential place for filters or summary views later
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 15) // Revert to smaller bottom padding
                // Removed background: .background(Color(UIColor.systemBackground))
                
                // --- Replace List with ScrollView + LazyVStack --- 
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 15) {
                        // Group entries by date, similar to Finances
                        // For simplicity here, just iterate sorted entries
                        ForEach(healthEntries.sorted(by: { $0.date > $1.date })) { entry in
                            // Entry Card Button
                            Button {
                                entryToEdit = entry
                            } label: {
                                // Entry Card Content
                                HealthEntryCardView(entry: entry)
                                    .padding()
                                    .background(neumorphicCardBackground()) // Apply drop shadow card style
                            }
                            .buttonStyle(.plain)
                            // No List-specific modifiers needed
                        }
                    } // End LazyVStack
                    .padding(.horizontal) // Padding for the cards
                    .padding(.bottom) // Bottom padding for scroll content
                    .padding(.top, 30) // Add top padding to the LazyVStack content
                } // End ScrollView
            } // End Main Content VStack
            .background( // Apply Inner Shadow (Shadow 4) to the VStack content
                 RoundedRectangle(cornerRadius: 20)
                     .fill(neumorphicBackgroundColor)
                     .shadow(color: darkInnerShadowColor, radius: darkInnerShadowBlur, x: darkInnerShadowX, y: darkInnerShadowY)
                     .shadow(color: lightInnerShadowColor, radius: lightInnerShadowBlur, x: lightInnerShadowX, y: lightInnerShadowY)
             )
             .clipShape(RoundedRectangle(cornerRadius: 20))
             .padding() // Padding around the inner-shadowed area
            
            // Floating Action Button - Apply Drop Shadow (Shadow 2)
            Button {
                showingAddEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic icon color
                    .frame(width: 60, height: 60) // Fixed size
                    .background(
                        Circle()
                            .fill(neumorphicBackgroundColor)
                            .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur, x: darkDropShadowX, y: darkDropShadowY)
                            .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur, x: lightDropShadowX, y: lightDropShadowY)
                    )
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
            .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)) // Style sheet background
            .presentationDetents([.large]) // Use appropriate detents
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
            .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)) // Style sheet background
            .presentationDetents([.large]) // Use appropriate detents
        }
    }
    
    // Helper function to create the neumorphic card background
    @ViewBuilder
    private func neumorphicCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(neumorphicBackgroundColor)
            .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
            .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
}

// MARK: - Health Entry Card View (Extracted for clarity)

struct HealthEntryCardView: View {
    let entry: HealthEntry
    
    // Date formatter specific to the card if needed, or use one from parent
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long // e.g., April 11, 2025
        formatter.timeStyle = .none
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.date, formatter: dateFormatter)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Mood
            if let mood = entry.mood {
                HStack(spacing: 4) {
                    Image(systemName: mood.icon)
                        .foregroundStyle(mood.color)
                    Text(mood.rawValue)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                }
                .font(.subheadline)
            }
            
            // Metrics Grid (Example using Grid for alignment)
            // Adjust columns as needed based on how many items are typical
            Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 5) {
                // Row 1
                GridRow {
                    if let weight = entry.weight {
                        // Format weight before passing to MetricView
                        let weightString = String(format: "%.1f lbs", weight)
                        MetricView(label: "Weight", value: weightString)
                    }
                    if let sleep = entry.sleepHours {
                        // Format sleep before passing to MetricView
                        let sleepString = String(format: "%.1f hr", sleep)
                         MetricView(label: "Sleep", value: sleepString)
                    }
                }
                // Row 2
                GridRow {
                    if let water = entry.waterIntake {
                        // Format water before passing to MetricView
                        let waterString = String(format: "%.0f fl oz", water)
                        MetricView(label: "Water", value: waterString)
                    }
                     if let rhr = entry.restingHR {
                        // RHR is likely Int, no specifier needed, just convert to String
                        MetricView(label: "RHR", value: "\(rhr) bpm")
                    }
                }
                // Row 3
                GridRow {
                     if let stress = entry.stressLevel {
                        // Stress uses rawValue which is String
                         MetricView(label: "Stress", value: stress.rawValue, color: stress.color)
                    }
                    if let hrv = entry.hrv {
                        // HRV is likely Int, no specifier needed, just convert to String
                        MetricView(label: "HRV", value: "\(hrv) ms")
                    }
                }
            }
            
            // Notes
            if let notes = entry.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Ensure VStack takes full width
    }
}

// MARK: - Metric Helper View

struct MetricView: View {
    let label: String
    let value: String
    var color: Color? = nil // Optional color dot
    
    var body: some View {
        HStack(spacing: 4) {
            if let color = color {
                 Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(label + ":")
                 .font(.caption)
                 .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
        }
    }
}

// MARK: - Preview

#Preview {
    HealthView()
} 