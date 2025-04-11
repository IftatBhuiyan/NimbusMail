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

    // Focus state management
    @FocusState private var focusedField: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
             HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(NeumorphicButtonStyle())
                Spacer()
                Text("Add Health Entry")
                    .font(.headline).fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                Spacer()
                Button("Save") {
                    if validateAndSave() {
                        isPresented = false
                    }
                }
                .buttonStyle(NeumorphicButtonStyle())
                .disabled(!computeIsValid()) // Use computeIsValid for disabling
             }
             .padding()
             .background(neumorphicBackgroundColor) // Consistent header background

            // Replace Form with ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { // Main content stack

                    // --- Always Visible Section (as Card) ---
                    SectionHeader(title: "Entry Details")
                    VStack(alignment: .leading, spacing: 15) {
                        DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                             .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                             .accentColor(Color(hex: "0D2750").opacity(0.8))
                    }
                    .padding()
                    .background(neumorphicCardBackground())
                    
                    // --- Dynamically Added Metrics Section (as Card) ---
                    SectionHeader(title: "Tracked Metrics")
                    VStack(alignment: .leading, spacing: 15) {
                        // Sort visible metrics for consistent order
                        ForEach(visibleMetrics.sorted(by: { $0.rawValue < $1.rawValue })) { metric in
                            metricInputView(for: metric)
                                .animation(.default, value: visibleMetrics)
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
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                    .padding(10) // Add some padding
                                    .frame(maxWidth: .infinity) // Make it full width
                                    .contentShape(Rectangle()) // Ensure the whole area is tappable
                            }
                            .buttonStyle(NeumorphicButtonStyle())
                            .frame(maxWidth: .infinity) // Ensure Menu takes full width
                        }
                    }
                    .padding()
                    .background(neumorphicCardBackground())
                    
                    // --- Notes Section (as Card) ---
                    SectionHeader(title: "Notes")
                    VStack {
                        TextEditor(text: $notes)
                            .frame(minHeight: 100, maxHeight: 200)
                            .scrollContentBackground(.hidden)
                            .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .background(neumorphicBackgroundColor)
                            .cornerRadius(10)
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
        } // End Outer VStack
    }
    
    // Function to add a metric to the visible set
    private func addMetric(_ metric: OptionalHealthMetric) {
        visibleMetrics.insert(metric)
    }

    // View Builder for specific metric input rows
    @ViewBuilder
    private func metricInputView(for metric: OptionalHealthMetric) -> some View {
        // Using InputRow structure for consistency
        HStack {
             Text(metric.rawValue) // Use rawValue as label
                 .foregroundColor(Color(hex: "0D2750").opacity(0.8))
             Spacer()
             metricSpecificControl(for: metric) // Separate view for the actual input
                 .multilineTextAlignment(.trailing)
                 .frame(maxWidth: .infinity, alignment: .trailing) // Align input to the right
        }
        .padding(.vertical, 5) // Add some vertical padding
    }

    // View Builder for the specific input control based on metric type
     @ViewBuilder
     private func metricSpecificControl(for metric: OptionalHealthMetric) -> some View {
         switch metric {
         case .weight:
             TextField("lbs", text: $weightString)
                 .keyboardType(.decimalPad)
                 .textFieldStyle(NeumorphicTextFieldStyle())
         case .mood:
             Picker("", selection: $selectedMood) { // Empty label as it's provided by InputRow
                 Text("Select").tag(nil as HealthEntry.Mood?) // Consistent placeholder
                 ForEach(HealthEntry.Mood.allCases) { mood in
                     HStack {
                         Image(systemName: mood.icon).foregroundStyle(mood.color)
                         Text(mood.rawValue).tag(mood as HealthEntry.Mood?)
                     }
                 }
             }
             .pickerStyle(.menu) // Use menu style for consistency
             .tint(Color(hex: "0D2750").opacity(0.8)) // Style tint
         case .sleep:
             TextField("hours", text: $sleepHoursString)
                 .keyboardType(.decimalPad)
                 .textFieldStyle(NeumorphicTextFieldStyle())
         case .restingHR:
             TextField("bpm", text: $restingHRString)
                 .keyboardType(.numberPad)
                 .textFieldStyle(NeumorphicTextFieldStyle())
         case .hrv:
             TextField("ms", text: $hrvString)
                 .keyboardType(.numberPad)
                 .textFieldStyle(NeumorphicTextFieldStyle())
         case .waterIntake:
             TextField("fl oz", text: $waterIntakeString)
                 .keyboardType(.decimalPad)
                 .textFieldStyle(NeumorphicTextFieldStyle())
         case .stressLevel:
              Picker("", selection: $selectedStress) { // Empty label
                  Text("Select").tag(nil as HealthEntry.StressLevel?) // Consistent placeholder
                  ForEach(HealthEntry.StressLevel.allCases) { level in
                      HStack {
                          Circle().fill(level.color).frame(width: 8, height: 8)
                          Text(level.rawValue).tag(level as HealthEntry.StressLevel?)
                      }
                  }
              }
              .pickerStyle(.menu) // Use menu style
              .tint(Color(hex: "0D2750").opacity(0.8)) // Style tint
         }
     }
    
    // Validation logic - PURELY checks validity without modifying state
    private func computeIsValid() -> Bool {
        for metric in visibleMetrics {
            let isValid: Bool
            switch metric {
            case .weight:
                 // Allow empty string OR valid double
                 isValid = weightString.isEmpty || Double(weightString) != nil
            case .sleep:
                 isValid = sleepHoursString.isEmpty || Double(sleepHoursString) != nil
            case .restingHR:
                 isValid = restingHRString.isEmpty || Int(restingHRString) != nil
            case .hrv:
                 isValid = hrvString.isEmpty || Int(hrvString) != nil
            case .waterIntake:
                 isValid = waterIntakeString.isEmpty || Double(waterIntakeString) != nil
            case .mood, .stressLevel:
                 isValid = true // Pickers are inherently valid (can be nil)
            }
            if !isValid { return false } // If any visible metric is invalid, the form is invalid
        }
        return true // All visible metrics are valid
    }
    
    // Save logic - Relies on computeIsValid already checking format
    private func validateAndSave() -> Bool {
        guard computeIsValid() else {
            print("Attempted to save with invalid data.")
            // Optionally show an alert to the user here
            return false
        }
        
        // Parse values only for visible metrics
        // Use nil-coalescing with optional try? for safer parsing
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
        return true // Indicate successful save
    }
} 