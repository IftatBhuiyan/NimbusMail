import SwiftUI

// Reuse the OptionalHealthMetric enum (or define it here if preferred)
// Assuming it's accessible or defined elsewhere/globally

struct EditHealthEntryView: View {
    // Input
    @State var entry: HealthEntry // Use @State for mutable copy
    let onUpdate: (HealthEntry) -> Void
    
    // Environment
    @Environment(\.dismiss) private var dismiss
    
    // --- Core Form State (initialized from entry) ---
    @State private var date: Date
    @State private var notes: String
    
    // --- Optional Metrics State ---
    // Holds the metrics currently added to the form
    @State private var visibleMetrics: Set<OptionalHealthMetric> = []
    
    // State for the input values (initialized from entry)
    @State private var weightString: String
    @State private var selectedMood: HealthEntry.Mood?
    @State private var sleepHoursString: String
    @State private var restingHRString: String
    @State private var hrvString: String
    @State private var waterIntakeString: String
    @State private var selectedStress: HealthEntry.StressLevel?

    // --- Validation State ---
    @State private var validationStates: [OptionalHealthMetric: Bool] = [:]
    
    // --- Computed Properties ---
    private var availableMetricsToAdd: [OptionalHealthMetric] {
        OptionalHealthMetric.allCases.filter { !visibleMetrics.contains($0) }
    }
    
    // Initializer
    init(entry: HealthEntry, onUpdate: @escaping (HealthEntry) -> Void) {
        _entry = State(initialValue: entry)
        self.onUpdate = onUpdate
        
        // Initialize core form state
        _date = State(initialValue: entry.date)
        _notes = State(initialValue: entry.notes ?? "")
        
        // Initialize optional input states
        _weightString = State(initialValue: entry.weight.map { String(format: "%.1f", $0) } ?? "")
        _selectedMood = State(initialValue: entry.mood)
        _sleepHoursString = State(initialValue: entry.sleepHours.map { String(format: "%.1f", $0) } ?? "")
        _restingHRString = State(initialValue: entry.restingHR.map { String($0) } ?? "")
        _hrvString = State(initialValue: entry.hrv.map { String($0) } ?? "")
        _waterIntakeString = State(initialValue: entry.waterIntake.map { String(format: "%.0f", $0) } ?? "")
        _selectedStress = State(initialValue: entry.stressLevel)
        
        // Determine initially visible metrics based on entry data
        var initialVisible: Set<OptionalHealthMetric> = []
        if entry.weight != nil { initialVisible.insert(.weight) }
        if entry.mood != nil { initialVisible.insert(.mood) }
        if entry.sleepHours != nil { initialVisible.insert(.sleep) }
        if entry.restingHR != nil { initialVisible.insert(.restingHR) }
        if entry.hrv != nil { initialVisible.insert(.hrv) }
        if entry.waterIntake != nil { initialVisible.insert(.waterIntake) }
        if entry.stressLevel != nil { initialVisible.insert(.stressLevel) }
        _visibleMetrics = State(initialValue: initialVisible)
        
        // Initialize validation states (assume valid initially)
        var initialValidation: [OptionalHealthMetric: Bool] = [:]
        for metric in OptionalHealthMetric.allCases {
            initialValidation[metric] = true
        }
         _validationStates = State(initialValue: initialValidation)
    }

    var body: some View {
        NavigationStack {
            Form {
                // --- Always Visible Section ---
                Section("Entry Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                // --- Dynamically Added Metrics Section ---
                Section("Tracked Metrics") {
                     ForEach(visibleMetrics.sorted(by: { $0.rawValue < $1.rawValue })) { metric in
                        metricInputView(for: metric)
                            .animation(.default, value: visibleMetrics)
                    }
                    
                    // "Add Metric" Button
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
                
                // --- Notes Section ---
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Health Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        if validateAndUpdate() {
                            dismiss()
                        }
                    }
                    .disabled(!computeIsValid())
                }
            }
            // No onChange needed here as removing is handled implicitly by not saving if not visible
        }
    }
    
    // Function to add a metric
    private func addMetric(_ metric: OptionalHealthMetric) {
        validationStates[metric] = true // Reset validation on add
        visibleMetrics.insert(metric)
    }

    // View Builder for metric inputs (Identical to Add view)
    @ViewBuilder
    private func metricInputView(for metric: OptionalHealthMetric) -> some View {
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
    
    // Update logic - Performs validation *and updates state* before parsing/saving
    private func validateAndUpdate() -> Bool {
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
        let moodValue = visibleMetrics.contains(.mood) ? selectedMood : nil
        let stressValue = visibleMetrics.contains(.stressLevel) ? selectedStress : nil

        // Create the updated entry using original ID
        let updatedEntry = HealthEntry(
            id: entry.id, // Keep original ID
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
        
        onUpdate(updatedEntry)
        return true
    }
} 