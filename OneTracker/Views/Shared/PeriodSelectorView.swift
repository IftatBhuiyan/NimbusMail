import SwiftUI

struct PeriodSelectorView: View {
    // Binding to update the selected period in ContentView
    @Binding var selectedPeriod: TimePeriod
    // Environment variable to dismiss the sheet
    @Environment(\.dismiss) var dismiss

    // State for custom date range pickers
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()

    // Track which preset is selected for UI state
    private enum PresetPeriod: Hashable {
        case daily, weekly, monthly, all, custom
    }
    @State private var selectedPreset: PresetPeriod = .all

    var body: some View {
        NavigationView {
            Form {
                Section("Select Time Period") {
                    Picker("", selection: $selectedPreset) {
                        Text(TimePeriod.all.displayName).tag(PresetPeriod.all)
                        Text(TimePeriod.daily.displayName).tag(PresetPeriod.daily)
                        Text(TimePeriod.weekly.displayName).tag(PresetPeriod.weekly)
                        Text(TimePeriod.monthly.displayName).tag(PresetPeriod.monthly)
                        Text(TimePeriod.custom(DateInterval()).displayName).tag(PresetPeriod.custom)
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedPreset) { _, newPreset in
                        updateSelectedPeriod(preset: newPreset)
                    }
                    .labelsHidden()
                }

                // Show custom date pickers only if custom is selected
                if selectedPreset == .custom {
                    Section("Custom Date Range") {
                        DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                            .onChange(of: customStartDate) { // Ensure end date >= start date
                                if customEndDate < customStartDate {
                                    customEndDate = customStartDate
                                }
                                updateSelectedPeriod(preset: .custom) // Update the period when dates change
                            }
                            .onChange(of: customEndDate) { // Update the period when dates change
                                updateSelectedPeriod(preset: .custom)
                            }
                    }
                }
            }
            .navigationTitle("Select Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Final update before dismissing (especially for custom)
                        updateSelectedPeriod(preset: selectedPreset)
                        dismiss()
                    }
                }
            }
            // Initialize state when view appears based on the bound selectedPeriod
            .onAppear(perform: initializeStateFromBinding)
        }
    }

    // Initialize local state based on the bound selectedPeriod
    private func initializeStateFromBinding() {
        switch selectedPeriod {
        case .daily:
            selectedPreset = .daily
        case .weekly:
            selectedPreset = .weekly
        case .monthly:
            selectedPreset = .monthly
        case .all:
            selectedPreset = .all
        case .custom(let interval):
            selectedPreset = .custom
            customStartDate = interval.start
            customEndDate = interval.end
        }
    }

    // Update the binding based on local state
    private func updateSelectedPeriod(preset: PresetPeriod) {
        switch preset {
        case .daily:
            selectedPeriod = .daily
        case .weekly:
            selectedPeriod = .weekly
        case .monthly:
            selectedPeriod = .monthly
        case .all:
            selectedPeriod = .all
        case .custom:
            // Ensure end date is at the very end of the selected day
            let endDateEndOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
            selectedPeriod = .custom(DateInterval(start: Calendar.current.startOfDay(for: customStartDate), end: endDateEndOfDay))
        }
    }
}

// Preview Provider
#Preview {
    // Create a wrapper view for the preview
    struct PreviewWrapper: View {
        @State var previewPeriod: TimePeriod = .monthly
        var body: some View {
            PeriodSelectorView(selectedPeriod: $previewPeriod)
        }
    }
    return PreviewWrapper()
} 