import SwiftUI
import SwiftData

// Removed FitnessActivity struct definition (moved to Models/FitnessActivity.swift)

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
            VStack(spacing: 0) {
                // Custom header similar to Finances
                HStack {
                    Text("Fitness")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    
                    // Time period selector
                    Picker("Time Period", selection: $selectedTimePeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.trailing)
                }
                .padding(.top)
                
                // Stats summary section
                VStack(spacing: 5) {
                    HStack {
                        Text("\(selectedTimePeriod.rawValue) Summary")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading)
                        
                        Text("\(periodStats.workouts) workouts")
                            .foregroundColor(.secondary)
                            .padding(.trailing)
                    }
                    
                    HStack(spacing: 20) {
                        // Duration stat
                        VStack {
                            Text("Duration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatDuration(periodStats.totalDuration))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Divider
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 1, height: 40)
                        
                        // Calories stat
                        VStack {
                            Text("Calories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(periodStats.totalCalories)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.top)
                
                // Activity list
                List {
                    Section("Recent Activities") {
                        ForEach(filterActivitiesByTimePeriod(fitnessActivities)) { activity in
                            // Wrap row content in a Button to make it tappable for editing
                            Button { // Action to set the activity to be edited
                                activityToEdit = activity
                            } label: { // The existing HStack is now the Button's label
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        // Display workout type and flame icons side-by-side
                                        HStack(spacing: 2) { // Add spacing between type and flames
                                            Text(activity.type)
                                                .font(.headline)
                                            
                                            // Display flame icons using if statements based on count
                                            if activity.intensity.flameCount >= 1 {
                                                Image(systemName: "flame.fill")
                                                    .foregroundStyle(activity.intensity.iconColor)
                                                    .font(.caption)
                                            }
                                            if activity.intensity.flameCount >= 2 {
                                                Image(systemName: "flame.fill")
                                                    .foregroundStyle(activity.intensity.iconColor)
                                                    .font(.caption)
                                            }
                                            if activity.intensity.flameCount >= 3 {
                                                Image(systemName: "flame.fill")
                                                    .foregroundStyle(activity.intensity.iconColor)
                                                    .font(.caption)
                                            }
                                        }
                                            
                                        Text(activity.date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        // Show additional type-specific metrics if available
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
                                        Text("\(formatDuration(activity.duration))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("\(activity.calories) cal")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } // End Button label
                            .buttonStyle(.plain) // Use plain style to keep list row appearance
                            .padding(.vertical, 5)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            // Floating Action Button (same style as Finance screen)
            Button(action: {
                showingAddWorkout = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
            .padding() // Add padding from the edges
            .padding(.bottom, 20) // Adjusted bottom padding
            .padding(.trailing, 10) // Adjusted right padding
        }
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

#Preview {
    FitnessView()
} 