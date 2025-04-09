import SwiftUI
import SwiftData

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

// View for adding a new workout
struct AddWorkoutView: View {
    @Binding var isPresented: Bool
    let workoutTypes: [String]
    let onSave: (FitnessActivity) -> Void
    
    @State private var selectedType = "Running"
    @State private var duration = "30"
    @State private var calories = "200"
    @State private var date = Date()
    @State private var notes = ""
    @State private var intensity: FitnessActivity.Intensity = .moderate
    
    // Type-specific fields
    @State private var distance = ""
    @State private var sets = ""
    @State private var reps = ""
    @State private var weight = ""
    @State private var pace = ""
    @State private var laps = ""
    @State private var elevationGain = ""
    @State private var heartRate = ""
    @State private var steps = ""
    @State private var route = ""
    @State private var style = ""
    
    // Swimming stroke types
    private let strokeTypes = ["Freestyle", "Breaststroke", "Backstroke", "Butterfly", "Mixed"]
    
    // Yoga styles
    private let yogaStyles = ["Hatha", "Vinyasa", "Ashtanga", "Yin", "Power", "Restorative", "Hot"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Workout type
                Section("Workout Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(workoutTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Basic details
                Section("Basic Details") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("Minutes", text: $duration)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Calories Burned")
                        Spacer()
                        TextField("Calories", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Intensity picker
                    Picker("Intensity", selection: $intensity) {
                        ForEach(FitnessActivity.Intensity.allCases, id: \.self) { level in
                            // Display only the text label for each option
                            Text(level.rawValue)
                                .tag(level)
                        }
                    }
                    
                    HStack {
                        Text("Heart Rate (avg)")
                        Spacer()
                        TextField("BPM", text: $heartRate)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                // Type-specific details
                if selectedType == "Running" || selectedType == "Walking" || selectedType == "Cycling" {
                    Section("Activity Details") {
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("miles", text: $distance)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        if selectedType == "Running" || selectedType == "Walking" {
                            HStack {
                                Text("Pace")
                                Spacer()
                                TextField("min/mile", text: $pace)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            if selectedType == "Walking" {
                                HStack {
                                    Text("Steps")
                                    Spacer()
                                    TextField("count", text: $steps)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                        
                        if selectedType == "Cycling" {
                            HStack {
                                Text("Elevation Gain")
                                Spacer()
                                TextField("feet", text: $elevationGain)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        
                        HStack {
                            Text("Route")
                            Spacer()
                            TextField("optional", text: $route)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                if selectedType == "Swimming" {
                    Section("Swimming Details") {
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("yards", text: $distance)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Laps")
                            Spacer()
                            TextField("count", text: $laps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Picker("Stroke", selection: $style) {
                            Text("Select").tag("")
                            ForEach(strokeTypes, id: \.self) { stroke in
                                Text(stroke).tag(stroke)
                            }
                        }
                    }
                }
                
                if selectedType == "Weights" {
                    Section("Weight Training Details") {
                        HStack {
                            Text("Sets")
                            Spacer()
                            TextField("count", text: $sets)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Reps")
                            Spacer()
                            TextField("count", text: $reps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("lbs", text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                if selectedType == "Yoga" {
                    Section("Yoga Details") {
                        Picker("Style", selection: $style) {
                            Text("Select").tag("")
                            ForEach(yogaStyles, id: \.self) { yogaStyle in
                                Text(yogaStyle).tag(yogaStyle)
                            }
                        }
                    }
                }
                
                if selectedType == "HIIT" {
                    Section("HIIT Details") {
                        HStack {
                            Text("Rounds")
                            Spacer()
                            TextField("count", text: $sets)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWorkout()
                    }
                }
            }
            .onChange(of: selectedType) {
                // Reset type-specific fields when changing workout type
                clearTypeSpecificFields()
            }
        }
    }
    
    private func clearTypeSpecificFields() {
        distance = ""
        sets = ""
        reps = ""
        weight = ""
        pace = ""
        laps = ""
        elevationGain = ""
        steps = ""
        route = ""
        style = ""
    }
    
    private func saveWorkout() {
        // Convert string inputs to integers with validation
        guard let durationInt = Int(duration), durationInt > 0,
              let caloriesInt = Int(calories), caloriesInt > 0 else {
            return
        }
        
        // Create the new activity
        var newActivity = FitnessActivity(
            type: selectedType,
            duration: durationInt,
            calories: caloriesInt,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            intensity: intensity
        )
        
        // Add type-specific details if provided
        if !distance.isEmpty, let distanceValue = Double(distance) {
            newActivity.distance = distanceValue
        }
        
        if !sets.isEmpty, let setsValue = Int(sets) {
            newActivity.sets = setsValue
        }
        
        if !reps.isEmpty, let repsValue = Int(reps) {
            newActivity.reps = repsValue
        }
        
        if !weight.isEmpty, let weightValue = Double(weight) {
            newActivity.weight = weightValue
        }
        
        if !pace.isEmpty, let paceValue = Double(pace) {
            newActivity.pace = paceValue
        }
        
        if !laps.isEmpty, let lapsValue = Int(laps) {
            newActivity.laps = lapsValue
        }
        
        if !elevationGain.isEmpty, let elevationValue = Double(elevationGain) {
            newActivity.elevationGain = elevationValue
        }
        
        if !heartRate.isEmpty, let heartRateValue = Int(heartRate) {
            newActivity.heartRate = heartRateValue
        }
        
        if !steps.isEmpty, let stepsValue = Int(steps) {
            newActivity.steps = stepsValue
        }
        
        if !route.isEmpty {
            newActivity.route = route
        }
        
        if !style.isEmpty {
            newActivity.style = style
        }
        
        // Save and dismiss
        onSave(newActivity)
        isPresented = false
    }
}

#Preview {
    FitnessView()
}

// MARK: - Edit Workout View

// View for editing an existing workout (similar to AddWorkoutView)
struct EditWorkoutView: View {
    // The activity being edited (passed in)
    @State var activity: FitnessActivity
    let workoutTypes: [String]
    let onUpdate: (FitnessActivity) -> Void // Closure to call when updated
    
    @Environment(\.dismiss) private var dismiss // To close the sheet

    // Local state for form fields, initialized from the activity
    @State private var selectedType: String
    @State private var duration: String
    @State private var calories: String
    @State private var date: Date
    @State private var notes: String
    @State private var intensity: FitnessActivity.Intensity
    @State private var distance: String
    @State private var sets: String
    @State private var reps: String
    @State private var weight: String
    @State private var pace: String
    @State private var laps: String
    @State private var elevationGain: String
    @State private var heartRate: String
    @State private var steps: String
    @State private var route: String
    @State private var style: String

    // Initialize local state from the passed-in activity
    init(activity: FitnessActivity, workoutTypes: [String], onUpdate: @escaping (FitnessActivity) -> Void) {
        // Use _ prefix to set initial value of @State properties
        _activity = State(initialValue: activity)
        self.workoutTypes = workoutTypes
        self.onUpdate = onUpdate

        // Initialize form state from the activity's properties
        _selectedType = State(initialValue: activity.type)
        _duration = State(initialValue: String(activity.duration))
        _calories = State(initialValue: String(activity.calories))
        _date = State(initialValue: activity.date)
        _notes = State(initialValue: activity.notes ?? "")
        _intensity = State(initialValue: activity.intensity)
        _distance = State(initialValue: activity.distance.map { String(format: "%.2f", $0) } ?? "")
        _sets = State(initialValue: activity.sets.map { String($0) } ?? "")
        _reps = State(initialValue: activity.reps.map { String($0) } ?? "")
        _weight = State(initialValue: activity.weight.map { String(format: "%.2f", $0) } ?? "")
        _pace = State(initialValue: activity.pace.map { String(format: "%.2f", $0) } ?? "")
        _laps = State(initialValue: activity.laps.map { String($0) } ?? "")
        _elevationGain = State(initialValue: activity.elevationGain.map { String(format: "%.2f", $0) } ?? "")
        _heartRate = State(initialValue: activity.heartRate.map { String($0) } ?? "")
        _steps = State(initialValue: activity.steps.map { String($0) } ?? "")
        _route = State(initialValue: activity.route ?? "")
        _style = State(initialValue: activity.style ?? "")
    }

    // Common Form content (extracted or duplicated from AddWorkoutView)
    private var formContent: some View {
        Form {
             // Workout type
                Section("Workout Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(workoutTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Basic details
                Section("Basic Details") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("Minutes", text: $duration)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Calories Burned")
                        Spacer()
                        TextField("Calories", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Intensity picker
                    Picker("Intensity", selection: $intensity) {
                        ForEach(FitnessActivity.Intensity.allCases, id: \.self) { level in
                            // Display only the text label for each option
                            Text(level.rawValue)
                                .tag(level)
                        }
                    }
                    
                    HStack {
                        Text("Heart Rate (avg)")
                        Spacer()
                        TextField("BPM", text: $heartRate)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                // Type-specific details (same logic as AddWorkoutView)
                 if selectedType == "Running" || selectedType == "Walking" || selectedType == "Cycling" {
                    Section("Activity Details") {
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("miles", text: $distance)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        if selectedType == "Running" || selectedType == "Walking" {
                            HStack {
                                Text("Pace")
                                Spacer()
                                TextField("min/mile", text: $pace)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            if selectedType == "Walking" {
                                HStack {
                                    Text("Steps")
                                    Spacer()
                                    TextField("count", text: $steps)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                        
                        if selectedType == "Cycling" {
                            HStack {
                                Text("Elevation Gain")
                                Spacer()
                                TextField("feet", text: $elevationGain)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        
                        HStack {
                            Text("Route")
                            Spacer()
                            TextField("optional", text: $route)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                if selectedType == "Swimming" {
                    Section("Swimming Details") {
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("yards", text: $distance)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Laps")
                            Spacer()
                            TextField("count", text: $laps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Picker("Stroke", selection: $style) {
                            Text("Select").tag("")
                            ForEach(strokeTypes, id: \.self) { stroke in
                                Text(stroke).tag(stroke)
                            }
                        }
                    }
                }
                
                if selectedType == "Weights" {
                    Section("Weight Training Details") {
                        HStack {
                            Text("Sets")
                            Spacer()
                            TextField("count", text: $sets)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Reps")
                            Spacer()
                            TextField("count", text: $reps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("lbs", text: $weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                if selectedType == "Yoga" {
                    Section("Yoga Details") {
                        Picker("Style", selection: $style) {
                            Text("Select").tag("")
                            ForEach(yogaStyles, id: \.self) { yogaStyle in
                                Text(yogaStyle).tag(yogaStyle)
                            }
                        }
                    }
                }
                
                if selectedType == "HIIT" {
                    Section("HIIT Details") {
                        HStack {
                            Text("Rounds")
                            Spacer()
                            TextField("count", text: $sets)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
        }
    }
    
    // Swimming stroke types (can be shared or kept separate)
    private let strokeTypes = ["Freestyle", "Breaststroke", "Backstroke", "Butterfly", "Mixed"]
    
    // Yoga styles (can be shared or kept separate)
    private let yogaStyles = ["Hatha", "Vinyasa", "Ashtanga", "Yin", "Power", "Restorative", "Hot"]

    var body: some View {
        NavigationStack {
            formContent // Use the extracted form content
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss() // Simply dismiss the sheet
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") { // Changed Save to Update
                        updateWorkout()
                    }
                }
            }
            .onChange(of: selectedType) { 
                 // Reset type-specific fields when changing workout type
                 // (Same logic as AddWorkoutView)
                clearTypeSpecificFields()
            }
        }
    }

    // Reset type-specific fields (same as AddWorkoutView)
    private func clearTypeSpecificFields() {
        distance = ""
        sets = ""
        reps = ""
        weight = ""
        pace = ""
        laps = ""
        elevationGain = ""
        steps = ""
        route = ""
        style = ""
    }

    // Function to update the activity object and call the update handler
    private func updateWorkout() {
        // Convert string inputs to integers/doubles with validation
        guard let durationInt = Int(duration), durationInt > 0,
              let caloriesInt = Int(calories), caloriesInt > 0 else {
            // Maybe show an alert to the user here
            return
        }

        // Create an updated activity object (can reuse the original id)
        var updatedActivity = FitnessActivity(
            id: activity.id, // Keep the original ID
            type: selectedType,
            duration: durationInt,
            calories: caloriesInt,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            intensity: intensity
        )

        // Add type-specific details (same parsing logic as saveWorkout)
         if !distance.isEmpty, let distanceValue = Double(distance) {
            updatedActivity.distance = distanceValue
        }
        
        if !sets.isEmpty, let setsValue = Int(sets) {
            updatedActivity.sets = setsValue
        }
        
        if !reps.isEmpty, let repsValue = Int(reps) {
            updatedActivity.reps = repsValue
        }
        
        if !weight.isEmpty, let weightValue = Double(weight) {
            updatedActivity.weight = weightValue
        }
        
        if !pace.isEmpty, let paceValue = Double(pace) {
            updatedActivity.pace = paceValue
        }
        
        if !laps.isEmpty, let lapsValue = Int(laps) {
            updatedActivity.laps = lapsValue
        }
        
        if !elevationGain.isEmpty, let elevationValue = Double(elevationGain) {
            updatedActivity.elevationGain = elevationValue
        }
        
        if !heartRate.isEmpty, let heartRateValue = Int(heartRate) {
            updatedActivity.heartRate = heartRateValue
        }
        
        if !steps.isEmpty, let stepsValue = Int(steps) {
            updatedActivity.steps = stepsValue
        }
        
        if !route.isEmpty {
            updatedActivity.route = route
        }
        
        if !style.isEmpty {
            updatedActivity.style = style
        }

        // Call the update handler with the modified activity
        onUpdate(updatedActivity)
        dismiss() // Dismiss the sheet
    }
} 