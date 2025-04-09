import SwiftUI

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