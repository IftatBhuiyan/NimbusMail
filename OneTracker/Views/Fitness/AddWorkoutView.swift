import SwiftUI

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