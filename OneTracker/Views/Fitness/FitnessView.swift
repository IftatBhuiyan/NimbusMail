import SwiftUI
import SwiftData

// Removed FitnessActivity struct definition (moved to Models/FitnessActivity.swift)

// MARK: - Neumorphism Colors
let neumorphicBackgroundColor = Color(hex: "E8EAEC")

// --- Shadow 2 (Drop Shadow) --- Used for FAB, Stats Card, List Rows
let darkDropShadowColor = Color(hex: "0D2750").opacity(0.16)
let darkDropShadowX: CGFloat = 28
let darkDropShadowY: CGFloat = 28
let darkDropShadowBlur: CGFloat = 50 / 2 // SwiftUI radius is roughly half the design blur

let lightDropShadowColor = Color.white.opacity(1.0)
let lightDropShadowX: CGFloat = -23
let lightDropShadowY: CGFloat = -23
let lightDropShadowBlur: CGFloat = 45 / 2 // SwiftUI radius is roughly half the design blur

// --- Shadow 4 (Inner Shadow) --- Used for Main Content Area Background
let lightInnerShadowColor = Color.white.opacity(0.64) // Opacity 64%
let lightInnerShadowX: CGFloat = -31
let lightInnerShadowY: CGFloat = -31
let lightInnerShadowBlur: CGFloat = 43 / 2

let darkInnerShadowColor = Color(hex: "0D2750").opacity(0.16) // Opacity 16%
let darkInnerShadowX: CGFloat = 26
let darkInnerShadowY: CGFloat = 26
let darkInnerShadowBlur: CGFloat = 48 / 2

// MARK: - Fitness View
struct FitnessView: View {
    // Sample workout types for quick selection
    private let workoutTypes = ["Running", "Walking", "Cycling", "Swimming", "Weights", "Yoga", "HIIT", "Other"]
    
    // State to track whether to show add workout sheet
    @State private var showingAddWorkout = false
    // State to track the activity being edited
    @State private var activityToEdit: FitnessActivity? = nil
    
    // State for fitness activities - would be replaced with @Query or another data source in a real app
    @State private var fitnessActivities: [FitnessActivity] = [
        FitnessActivity(
            type: "Running", 
            duration: 30, 
            calories: 320, 
            date: Date().addingTimeInterval(-86400), 
            notes: "Morning run in the park", 
            intensity: .moderate
        ),
        FitnessActivity(
            type: "Weights", 
            duration: 45, 
            calories: 280, 
            date: Date().addingTimeInterval(-172800), 
            notes: "Upper body day", 
            intensity: .intense
        ),
        FitnessActivity(
            type: "Yoga", 
            duration: 60, 
            calories: 200, 
            date: Date().addingTimeInterval(-259200), 
            notes: "Relaxing session", 
            intensity: .light
        )
    ]
    
    // Time period selection
    @State private var selectedTimePeriod: TimePeriod = .weekly
    
    enum TimePeriod: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case yearly = "Yearly"
    }
    
    // Calculate stats for selected time period
    private var periodStats: (workouts: Int, totalDuration: Int, totalCalories: Int) {
        let filteredActivities = filterActivitiesByTimePeriod(fitnessActivities)
        
        let workouts = filteredActivities.count
        let totalDuration = filteredActivities.reduce(0) { $0 + $1.duration }
        let totalCalories = filteredActivities.reduce(0) { $0 + $1.calories }
        
        return (workouts, totalDuration, totalCalories)
    }
    
    // Filter activities based on selected time period
    private func filterActivitiesByTimePeriod(_ activities: [FitnessActivity]) -> [FitnessActivity] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimePeriod {
        case .daily:
            return activities.filter { calendar.isDateInToday($0.date) }
        case .weekly:
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                return []
            }
            return activities.filter { $0.date >= weekStart && $0.date < weekEnd }
        case .monthly:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return []
            }
            return activities.filter { $0.date >= monthStart && $0.date < monthEnd }
        case .yearly:
            guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) else {
                return []
            }
            return activities.filter { $0.date >= yearStart && $0.date < yearEnd }
        }
    }
    
    // Format minutes as hours and minutes
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // Format distance based on activity type
    private func formatDistance(_ distance: Double?, forType type: String) -> String? {
        guard let distance = distance else { return nil }
        
        if type == "Swimming" {
            return "\(Int(distance)) yards"
        } else {
            let distanceFormatted = String(format: "%.2f", distance)
            return "\(distanceFormatted) mi"
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Set the background color for the whole view
            neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)

            // Apply Inner Shadow (Shadow 4) effect to the main content VStack
            VStack(spacing: 0) { // Content that will appear inside the "pressed" area
                // Custom header (Part of the inner shadowed content)
                HStack {
                    Text("Fitness")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)

                    Picker("Time Period", selection: $selectedTimePeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.trailing)
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 10)

                // Stats summary section - Apply Drop Shadow (Shadow 2) - Should float *out*
                VStack(spacing: 5) {
                     HStack {
                         Text("\(selectedTimePeriod.rawValue) Summary")
                             .font(.headline)
                             .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                             .frame(maxWidth: .infinity, alignment: .leading)
                             .padding([.leading, .top]) // Add top padding

                         Text("\(periodStats.workouts) workouts")
                             .foregroundColor(.secondary)
                             .padding([.trailing, .top]) // Add top padding
                     }
                     .padding(.bottom, 15) // Increased from 5 to 15

                    // Revert this HStack to Drop Shadow (Shadow 2)
                    HStack(spacing: 20) {
                        // Duration stat
                        VStack {
                            Text("Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDuration(periodStats.totalDuration))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)

                        // Divider
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1, height: 40)

                        // Calories stat
                        VStack {
                            Text("Calories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(periodStats.totalCalories)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal)
                    // Apply Drop Shadow (Shadow 2)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(neumorphicBackgroundColor)
                            // Use Drop Shadow parameters
                            .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur, x: darkDropShadowX, y: darkDropShadowY)
                            .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur, x: lightDropShadowX, y: lightDropShadowY)
                    )
                    .padding(.horizontal) // Padding around the card
                    .padding(.bottom, 10)
                }
                .padding(.top) // Space between header and stats card

                // --- Replace List with ScrollView + LazyVStack --- 
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 15) { // Spacing between items in the stack
                        // Section Header Text
                        Text("Recent Activities")
                           .font(.title3)
                           .fontWeight(.semibold)
                           .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                           .padding(.leading) // Align with card content
                           .padding(.bottom, 5) // Space below header
                           // .textCase(nil) // Not needed outside List Section

                        // Activity Cards
                        ForEach(filterActivitiesByTimePeriod(fitnessActivities)) { activity in
                             // Button wraps the styled content
                             Button {
                                 activityToEdit = activity
                             } label: {
                                 // Row Content (Button Label) - Apply Drop Shadow (Shadow 2)
                                 HStack { // This is the content that gets the shadow
                                     VStack(alignment: .leading, spacing: 5) {
                                        // ... (Existing content: Type, flames, date, distance, notes)
                                        HStack(spacing: 4) {
                                            Text(activity.type)
                                                .font(.headline)
                                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))

                                            ForEach(0..<activity.intensity.flameCount, id: \.self) { _ in
                                                 Image(systemName: "flame.fill")
                                                     .foregroundStyle(activity.intensity.iconColor)
                                                     .font(.caption)
                                            }
                                        }

                                        Text(activity.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let distance = formatDistance(activity.distance, forType: activity.type) {
                                            Text(distance)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        if let notes = activity.notes, !notes.isEmpty {
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                     }

                                     Spacer()

                                     VStack(alignment: .trailing, spacing: 5) {
                                         // ... (Existing content: Duration, Calories)
                                        Text("\(formatDuration(activity.duration))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color(hex: "0D2750").opacity(0.8))

                                        Text("\(activity.calories) cal")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                     }
                                 } // End of HStack for row content
                                 .padding() // Padding *inside* the background
                                 .background( // Background and Drop Shadow
                                     RoundedRectangle(cornerRadius: 10)
                                         .fill(neumorphicBackgroundColor)
                                         .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
                                         .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
                                 )
                             } // End Button Label
                             .buttonStyle(.plain)
                            // No need for List-specific modifiers like listRowInsets, listRowBackground
                         } // End ForEach
                    } // End LazyVStack
                    .padding(.horizontal) // Add horizontal padding to the stack content (keeping cards from edges)
                    .padding(.bottom) // Add some padding at the bottom of the scroll content
                } // End ScrollView
                // Remove List specific modifiers that were here
                // .listStyle(.plain)
                // .scrollContentBackground(.hidden)

            } // End Main Content VStack
            // Apply Inner Shadow (Shadow 4) to the VStack content by applying shadow to background and clipping
             .background(
                  RoundedRectangle(cornerRadius: 20) // Define the shape for the inner shadow area
                      .fill(neumorphicBackgroundColor) // Background color of the shape
                      // Apply shadows to the background shape itself to create the inner effect
                      .shadow(color: darkInnerShadowColor, radius: darkInnerShadowBlur, x: darkInnerShadowX, y: darkInnerShadowY)
                      .shadow(color: lightInnerShadowColor, radius: lightInnerShadowBlur, x: lightInnerShadowX, y: lightInnerShadowY)
              )
              .clipShape(RoundedRectangle(cornerRadius: 20)) // Clip the content (header, stats, list)
              .padding() // Add padding around the inner-shadowed area

            // Floating Action Button (FAB) - Unchanged
            Button(action: {
                showingAddWorkout = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                    .frame(width: 60, height: 60)
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

        } // End ZStack
        .sheet(isPresented: $showingAddWorkout) { // Sheet for Adding
            AddWorkoutView(
                isPresented: $showingAddWorkout,
                workoutTypes: workoutTypes,
                onSave: { newActivity in
                    fitnessActivities.insert(newActivity, at: 0)
                }
            )
        }
        // Add sheet modifier for Editing
        .sheet(item: $activityToEdit) { activity in
            // Pass the activity and an update handler to EditWorkoutView
            EditWorkoutView(
                activity: activity, 
                workoutTypes: workoutTypes,
                onUpdate: { updatedActivity in
                    // Find the index of the activity and update it in the array
                    if let index = fitnessActivities.firstIndex(where: { $0.id == updatedActivity.id }) {
                        fitnessActivities[index] = updatedActivity
                    }
                }
            )
        }
    }
}

// Add Color extension for hex values if not already present globally
// Consider moving this to a separate Utilities file
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0) // Default to black for invalid hex
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    FitnessView()
} 