import SwiftUI

// Removed OptionalHealthMetric enum (moved to Models/OptionalHealthMetric.swift)

struct AddHealthEntryView: View {
    @Binding var isPresented: Bool
    let onSave: (HealthEntry) -> Void
    
    // --- Core Form State ---
    @State private var date: Date = Date()
    @State private var notes: String = ""
    
    // --- Optional Metrics State ---
    // Holds the metrics currently added to the form
    @State private var visibleMetrics: Set<OptionalHealthMetric> = []
    
    // State for the input values of optional fields
    @State private var weightString: String = ""
    @State private var selectedMood: HealthEntry.Mood? = nil
    @State private var sleepHoursString: String = ""
    @State private var restingHRString: String = ""
    @State private var hrvString: String = ""
    @State private var waterIntakeString: String = ""
    @State private var selectedStress: HealthEntry.StressLevel? = nil

    // --- Validation State ---
    @State private var validationStates: [OptionalHealthMetric: Bool] = [:] // Track validity per metric

    // --- Computed Properties ---
    // Metrics available to be added (not already visible)
    private var availableMetricsToAdd: [OptionalHealthMetric] {
        OptionalHealthMetric.allCases.filter { !visibleMetrics.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                // --- Always Visible Section ---
                Section("Entry Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                // --- Dynamically Added Metrics Section ---
                // Display input fields only for metrics the user has added
                Section("Tracked Metrics") {
                    // Sort visible metrics for consistent order (optional)
                    ForEach(visibleMetrics.sorted(by: { $0.rawValue < $1.rawValue })) { metric in
                        metricInputView(for: metric)
                            .animation(.default, value: visibleMetrics) // Animate adding/removing
                    }
                    
                    // "Add Metric" Button - only show if there are metrics left to add
                    if !availableMetricsToAdd.isEmpty {
                        Menu {
                            ForEach(availableMetricsToAdd) { metric in
                                Button {
                                    addMetric(metric)
                                } label: {
                                    Label(metric.rawValue, systemImage: metric.iconName)
                                }
                            }
                        } label: {
                            Label("Add Metric", systemImage: "plus.circle.fill")
                        }
                    }
                }
                
                // --- Notes Section (Always Visible) ---
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Health Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if validateAndSave() {
                            isPresented = false
                        }
                    }
                    // Use computeIsValid for disabling the button
                    .disabled(!computeIsValid())
                }
            }
        }
    }
    
    // Function to add a metric to the visible set
    private func addMetric(_ metric: OptionalHealthMetric) {
        // Reset validation state for the metric when adding it
        validationStates[metric] = true
        visibleMetrics.insert(metric)
    }

    // View Builder for specific metric input rows
    @ViewBuilder
    private func metricInputView(for metric: OptionalHealthMetric) -> some View {
        // Use a switch or if/else to return the correct input view
        switch metric {
        case .weight:
            HStack {
                Text("Weight")
                Spacer()
                TextField("lbs", text: $weightString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .border(validationStates[metric, default: true] ? Color.clear : Color.red)
            }
        case .mood:
            Picker("Mood", selection: $selectedMood) {
                Text("None").tag(nil as HealthEntry.Mood?)
                ForEach(HealthEntry.Mood.allCases) { mood in
                    HStack {
                        Image(systemName: mood.icon).foregroundStyle(mood.color)
                        Text(mood.rawValue).tag(mood as HealthEntry.Mood?)
                    }
                }
            }
        case .sleep:
            HStack {
                Text("Sleep")
                Spacer()
                TextField("hours", text: $sleepHoursString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .border(validationStates[metric, default: true] ? Color.clear : Color.red)
            }
        case .restingHR:
            HStack {
                Text("Resting HR")
                Spacer()
                TextField("bpm", text: $restingHRString)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .border(validationStates[metric, default: true] ? Color.clear : Color.red)
            }
        case .hrv:
            HStack {
                Text("HRV")
                Spacer()
                TextField("ms", text: $hrvString)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .border(validationStates[metric, default: true] ? Color.clear : Color.red)
            }
        case .waterIntake:
            HStack {
                Text("Water Intake")
                Spacer()
                TextField("fl oz", text: $waterIntakeString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .border(validationStates[metric, default: true] ? Color.clear : Color.red)
            }
        case .stressLevel:
             Picker("Stress Level", selection: $selectedStress) {
                 Text("None").tag(nil as HealthEntry.StressLevel?)
                 ForEach(HealthEntry.StressLevel.allCases) { level in
                     HStack {
                         Circle().fill(level.color).frame(width: 8, height: 8)
                         Text(level.rawValue).tag(level as HealthEntry.StressLevel?)
                     }
                 }
             }
        }
    }
    
    // Validation logic - PURELY checks validity without modifying state
    private func computeIsValid() -> Bool {
        for metric in visibleMetrics {
            let isValid: Bool
            switch metric {
            case .weight:
                isValid = Double(weightString) != nil || weightString.isEmpty
            case .sleep:
                isValid = Double(sleepHoursString) != nil || sleepHoursString.isEmpty
            case .restingHR:
                 isValid = Int(restingHRString) != nil || restingHRString.isEmpty
            case .hrv:
                 isValid = Int(hrvString) != nil || hrvString.isEmpty
            case .waterIntake:
                 isValid = Double(waterIntakeString) != nil || waterIntakeString.isEmpty
            case .mood, .stressLevel:
                 isValid = true // Pickers are inherently valid
            }
            if !isValid { return false } // If any visible metric is invalid, the entry is invalid
        }
        return true // All visible metrics are valid
    }
    
    // Save logic - Performs validation *and updates state* before parsing/saving
    private func validateAndSave() -> Bool {
        var allValid = true
        // Reset validation UI state for all potentially visible metrics
        for metric in OptionalHealthMetric.allCases {
            validationStates[metric] = true
        }
        
        // Validate *and update UI state* only for the metrics currently shown
        for metric in visibleMetrics {
            var isMetricValid = true
            switch metric {
             case .weight:
                isMetricValid = Double(weightString) != nil || weightString.isEmpty
            case .sleep:
                isMetricValid = Double(sleepHoursString) != nil || sleepHoursString.isEmpty
            case .restingHR:
                 isMetricValid = Int(restingHRString) != nil || restingHRString.isEmpty
            case .hrv:
                 isMetricValid = Int(hrvString) != nil || hrvString.isEmpty
            case .waterIntake:
                 isMetricValid = Double(waterIntakeString) != nil || waterIntakeString.isEmpty
            case .mood, .stressLevel:
                 isMetricValid = true // Pickers are inherently valid or nil
            }
            validationStates[metric] = isMetricValid // Update UI state here
            if !isMetricValid {
                allValid = false // Mark overall entry as invalid
            }
        }

        // Only proceed if all visible metrics passed validation
        guard allValid else { return false }
        
        // Parse values only for visible metrics (safe now)
        let weightValue = visibleMetrics.contains(.weight) ? Double(weightString) : nil
        let sleepValue = visibleMetrics.contains(.sleep) ? Double(sleepHoursString) : nil
        let rhrValue = visibleMetrics.contains(.restingHR) ? Int(restingHRString) : nil
        let hrvValue = visibleMetrics.contains(.hrv) ? Int(hrvString) : nil
        let waterValue = visibleMetrics.contains(.waterIntake) ? Double(waterIntakeString) : nil
        
        // Mood and Stress are directly from state, but only included if visible
        let moodValue = visibleMetrics.contains(.mood) ? selectedMood : nil
        let stressValue = visibleMetrics.contains(.stressLevel) ? selectedStress : nil

        // Create the entry
        let newEntry = HealthEntry(
            date: date,
            weight: weightValue,
            mood: moodValue,
            sleepHours: sleepValue,
            notes: notes.isEmpty ? nil : notes,
            restingHR: rhrValue,
            hrv: hrvValue,
            waterIntake: waterValue,
            stressLevel: stressValue
        )
        
        onSave(newEntry)
        return true
    }
} 