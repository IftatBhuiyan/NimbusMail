import SwiftUI

// View for adding a new workout
struct AddWorkoutView: View {
    @Binding var isPresented: Bool
    let workoutTypes: [String]
    let onSave: (FitnessActivity) -> Void
    
    // Form State
    @State private var selectedType = "Running"
    @State private var duration = "30"
    @State private var calories = "200"
    @State private var date = Date()
    @State private var notes = ""
    @State private var intensity: FitnessActivity.Intensity = .moderate
    
    // Type-specific fields state
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
    
    // Focus state management
    @FocusState private var focusedField: Bool // Simple boolean focus state for now

    // Data for Pickers
    private let strokeTypes = ["Freestyle", "Breaststroke", "Backstroke", "Butterfly", "Mixed"]
    private let yogaStyles = ["Hatha", "Vinyasa", "Ashtanga", "Yin", "Power", "Restorative", "Hot"]
    
    var body: some View {
        // Replace NavigationStack with VStack
        VStack(spacing: 0) {
            // Custom Header
             HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(NeumorphicButtonStyle())
                Spacer()
                Text("Add Workout") // Use static title
                    .font(.headline).fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                Spacer()
                Button("Save") { saveWorkout() }
                    .buttonStyle(NeumorphicButtonStyle())
                    .disabled(!isValidForm()) // Add validation check for save button
             }
             .padding()
             .background(neumorphicBackgroundColor) // Consistent header background

            // Replace Form with ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { // Main content stack
                    
                    // --- Workout Type Card --- 
                    SectionHeader(title: "Workout Type")
                    VStack {
                        // Wrap Picker in InputRow
                        InputRow(label: "Type") {
                            Picker("Type", selection: $selectedType) {
                                ForEach(workoutTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color(hex: "0D2750").opacity(0.8))
                        }
                    }
                    .padding()
                    .background(neumorphicCardBackground())
                    
                    // --- Basic Details Card --- 
                    SectionHeader(title: "Basic Details")
                    VStack(alignment: .leading, spacing: 15) {
                        InputRow(label: "Duration") {
                            TextField("Minutes", text: $duration)
                                .keyboardType(.numberPad)
                        }
                        InputRow(label: "Calories Burned") {
                            TextField("Calories", text: $calories)
                                .keyboardType(.numberPad)
                        }
                        InputRow(label: "Heart Rate (avg)") {
                            TextField("BPM", text: $heartRate)
                                .keyboardType(.numberPad)
                        }
                        
                        // Wrap Picker in InputRow
                        InputRow(label: "Intensity") {
                            Picker("Intensity", selection: $intensity) {
                                ForEach(FitnessActivity.Intensity.allCases, id: \.self) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                            // .background(neumorphicBackgroundColor.opacity(0.6)) // Let InputRow handle layout
                            // .cornerRadius(8) // Segmented style provides its own look
                        }
                        
                        DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                             .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                             .accentColor(Color(hex: "0D2750").opacity(0.8))
                    }
                    .padding()
                    .background(neumorphicCardBackground())

                    // --- Dynamic Activity Details Card --- 
                     // Conditionally show based on selectedType
                     if !typeSpecificSectionTitle.isEmpty {
                        SectionHeader(title: typeSpecificSectionTitle)
                        VStack(alignment: .leading, spacing: 15) {
                            // Include relevant fields based on selectedType
                            if selectedType == "Running" || selectedType == "Walking" || selectedType == "Cycling" {
                                InputRow(label: "Distance") {
                                    TextField(selectedType == "Swimming" ? "yards" : "miles", text: $distance)
                                        .keyboardType(.decimalPad)
                                }
                            }
                             if selectedType == "Running" || selectedType == "Walking" {
                                 InputRow(label: "Pace") {
                                    TextField("min/mile", text: $pace)
                                        .keyboardType(.decimalPad)
                                }
                            }
                            if selectedType == "Walking" {
                                InputRow(label: "Steps") {
                                    TextField("count", text: $steps)
                                        .keyboardType(.numberPad)
                                }
                            }
                             if selectedType == "Cycling" {
                                 InputRow(label: "Elevation Gain") {
                                    TextField("feet", text: $elevationGain)
                                        .keyboardType(.decimalPad)
                                }
                            }
                            if selectedType == "Running" || selectedType == "Walking" || selectedType == "Cycling" {
                                InputRow(label: "Route") {
                                    TextField("optional", text: $route)
                                }
                            }
                             if selectedType == "Swimming" {
                                InputRow(label: "Distance") { // Repeated Distance for swimming units
                                    TextField("yards", text: $distance)
                                        .keyboardType(.decimalPad)
                                }
                                 InputRow(label: "Laps") {
                                    TextField("count", text: $laps)
                                        .keyboardType(.numberPad)
                                }
                                Picker("Stroke", selection: $style) {
                                    Text("Select").tag("")
                                    ForEach(strokeTypes, id: \.self) { stroke in Text(stroke).tag(stroke) }
                                }
                                .tint(Color(hex: "0D2750").opacity(0.8))
                            }
                            if selectedType == "Weights" {
                                InputRow(label: "Sets") {
                                    TextField("count", text: $sets)
                                        .keyboardType(.numberPad)
                                }
                                InputRow(label: "Reps") {
                                    TextField("count", text: $reps)
                                        .keyboardType(.numberPad)
                                }
                                InputRow(label: "Weight") {
                                    TextField("lbs", text: $weight)
                                        .keyboardType(.decimalPad)
                                }
                            }
                            if selectedType == "Yoga" {
                                Picker("Style", selection: $style) {
                                    Text("Select").tag("")
                                    ForEach(yogaStyles, id: \.self) { yogaStyle in Text(yogaStyle).tag(yogaStyle) }
                                }
                                .tint(Color(hex: "0D2750").opacity(0.8))
                            }
                            if selectedType == "HIIT" {
                                InputRow(label: "Rounds") {
                                    TextField("count", text: $sets) // Reusing sets state for rounds
                                        .keyboardType(.numberPad)
                                }
                            }
                        }
                        .padding()
                        .background(neumorphicCardBackground())
                     }

                    // --- Notes Card --- 
                    SectionHeader(title: "Notes")
                    VStack {
                        TextEditor(text: $notes)
                             .frame(minHeight: 100, maxHeight: 200)
                             .scrollContentBackground(.hidden) // Allow background color to show
                             .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) // Add padding for text
                             .background(neumorphicBackgroundColor) // Apply background color directly
                             .cornerRadius(10) // Apply corner radius
                              // Explicit focus management for TextEditor might be needed
                             .focused($focusedField)
                    }
                     .padding()
                     .background(neumorphicCardBackground())
                    
                } // End Main content VStack
                .padding() // Padding around all cards
            } // End ScrollView
             .background(neumorphicBackgroundColor) // Match background
             .ignoresSafeArea(.keyboard, edges: .bottom)
             .onTapGesture { focusedField = false } // Dismiss keyboard on tap
             .onChange(of: selectedType) { _, _ in
                clearTypeSpecificFields()
             }
        } // End Outer VStack
    }
    
    // Helper to get dynamic section title
    private var typeSpecificSectionTitle: String {
        switch selectedType {
            case "Running", "Walking", "Cycling": return "Activity Details"
            case "Swimming": return "Swimming Details"
            case "Weights": return "Weight Training Details"
            case "Yoga": return "Yoga Details"
            case "HIIT": return "HIIT Details"
            default: return "" // No specific section for "Other"
        }
    }
    
    // Helper View for Input Rows (Label + TextField)
    private struct InputRow<Content: View>: View {
        let label: String
        @ViewBuilder let content: Content

        var body: some View {
            HStack {
                Text(label)
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                Spacer()
                content
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(NeumorphicTextFieldStyle())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    private func isValidForm() -> Bool {
         // Basic validation: duration and calories must be positive numbers
         guard let durationInt = Int(duration), durationInt > 0, 
               let caloriesInt = Int(calories), caloriesInt > 0 else {
             return false
         }
         // Add more specific validation based on workout type if needed
         return true
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
        // Don't clear heart rate as it's in basic details now
    }
    
    private func saveWorkout() {
        guard isValidForm(), // Use validation check
              let durationInt = Int(duration),
              let caloriesInt = Int(calories) else {
            // Optionally show an alert for invalid data
            print("Invalid data for saving workout")
            return
        }
        
        var newActivity = FitnessActivity(
            type: selectedType,
            duration: durationInt,
            calories: caloriesInt,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            intensity: intensity
        )
        
        // Add optional fields if they have valid values
        if !distance.isEmpty, let val = Double(distance) { newActivity.distance = val }
        if !sets.isEmpty, let val = Int(sets) { newActivity.sets = val }
        if !reps.isEmpty, let val = Int(reps) { newActivity.reps = val }
        if !weight.isEmpty, let val = Double(weight) { newActivity.weight = val }
        if !pace.isEmpty, let val = Double(pace) { newActivity.pace = val }
        if !laps.isEmpty, let val = Int(laps) { newActivity.laps = val }
        if !elevationGain.isEmpty, let val = Double(elevationGain) { newActivity.elevationGain = val }
        if !heartRate.isEmpty, let val = Int(heartRate) { newActivity.heartRate = val }
        if !steps.isEmpty, let val = Int(steps) { newActivity.steps = val }
        if !route.isEmpty { newActivity.route = route }
        if !style.isEmpty { newActivity.style = style }
        
        onSave(newActivity)
        isPresented = false
    }
} 