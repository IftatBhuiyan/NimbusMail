import SwiftUI
import SwiftData

struct PlanningView: View {
    // State variables for budgets and goals
    @State private var monthlyBudget: String = UserDefaults.standard.string(forKey: "monthlyBudget") ?? "1000.00"
    @State private var savingsGoal: String = UserDefaults.standard.string(forKey: "savingsGoal") ?? "5000.00"
    @State private var savingsDeadline = UserDefaults.standard.object(forKey: "savingsDeadline") as? Date ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())!
    
    // State for edit mode
    @State private var isEditingBudget = false
    @State private var isEditingSavings = false
    
    // Access transactions from SwiftData to calculate budget progress
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    // Calculate current month's spending
    private var currentMonthSpending: Double {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: Date()) else {
            return 0.0
        }
        
        return transactions
            .filter { monthInterval.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Calculate budget progress
    private var budgetProgress: Double {
        guard let budget = Double(monthlyBudget), budget > 0 else { return 0 }
        return min(currentMonthSpending / budget, 1.0)
    }
    
    // Determine progress bar color based on budget usage
    private var progressColor: Color {
        switch budgetProgress {
        case 0..<0.6:
            return .green       // Good: Under 60% of budget
        case 0.6..<0.85:
            return .yellow     // Warning: 60-85% of budget
        default:
            return .red        // Alert: Over 85% of budget
        }
    }
    
    // Format currency
    private func formatCurrency(_ value: Double) -> String {
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header to match Finances view
            HStack {
                Text("Planning")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
                
                // Reset button
                Button {
                    // Reset budget and spent values to default
                    monthlyBudget = "1000.00"
                    savingsGoal = "5000.00"
                    savingsDeadline = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
                    saveMonthlyBudget()
                    saveSavingsGoal()
                    saveSavingsDeadline()
                    isEditingBudget = false
                    isEditingSavings = false
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .padding()
                }
            }
            .padding(.top)
            
            List {
                // Monthly Budget Section
                Section("Monthly Budget") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Budget:")
                            Spacer()
                            if isEditingBudget {
                                TextField("Amount", text: $monthlyBudget)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 120)
                                Button("Save") {
                                    saveMonthlyBudget()
                                    isEditingBudget = false
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                .padding(.leading, 5)
                            } else {
                                Text(formatCurrency(Double(monthlyBudget) ?? 0))
                                    .fontWeight(.medium)
                                Button {
                                    isEditingBudget = true
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // Progress bar
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Monthly Progress:")
                                .font(.subheadline)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 20)
                                    
                                    // Progress with color based on progress percentage
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(progressColor)
                                        .frame(width: geometry.size.width * budgetProgress, height: 20)
                                        .animation(.spring(), value: budgetProgress)
                                }
                            }
                            .frame(height: 20)
                            
                            HStack {
                                Text("Spent: \(formatCurrency(currentMonthSpending))")
                                Spacer()
                                if let budget = Double(monthlyBudget) {
                                    Text("Remaining: \(formatCurrency(max(budget - currentMonthSpending, 0)))")
                                        .foregroundColor(budget < currentMonthSpending ? .red : .primary)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
                
                // Savings Goal Section
                Section("Savings Goal") {
                    HStack {
                        Text("Target Amount:")
                        Spacer()
                        if isEditingSavings {
                            TextField("Goal", text: $savingsGoal)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 120)
                            Button("Save") {
                                saveSavingsGoal()
                                isEditingSavings = false
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .padding(.leading, 5)
                        } else {
                            Text(formatCurrency(Double(savingsGoal) ?? 0))
                                .fontWeight(.medium)
                            Button {
                                isEditingSavings = true
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    DatePicker("Target Date", selection: $savingsDeadline, displayedComponents: .date)
                        .onChange(of: savingsDeadline) { saveSavingsDeadline() }
                    
                    // Calculate and show monthly savings needed
                    if let goalAmount = Double(savingsGoal), goalAmount > 0 {
                        let months = max(Calendar.current.dateComponents([.month], from: Date(), to: savingsDeadline).month ?? 1, 1)
                        let monthlySavingsNeeded = goalAmount / Double(months)
                        
                        HStack {
                            Text("Monthly savings needed:")
                            Spacer()
                            Text(formatCurrency(monthlySavingsNeeded))
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                // Tips Section
                Section("Financial Tips") {
                    TipView(title: "50/30/20 Rule", 
                           description: "Try to allocate 50% of your budget to needs, 30% to wants, and 20% to savings.")
                    
                    TipView(title: "Track Recurring Expenses", 
                           description: "Review your subscriptions regularly to avoid unnecessary recurring charges.")
                    
                    TipView(title: "Emergency Fund", 
                           description: "Aim to save 3-6 months of expenses for emergencies.")
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    // Save values to UserDefaults
    private func saveMonthlyBudget() {
        // Validate the input is a valid number
        if let _ = Double(monthlyBudget) {
            UserDefaults.standard.set(monthlyBudget, forKey: "monthlyBudget")
        } else {
            // If invalid, revert to the previous valid value
            monthlyBudget = UserDefaults.standard.string(forKey: "monthlyBudget") ?? "1000.00"
        }
    }
    
    private func saveSavingsGoal() {
        // Validate the input is a valid number
        if let _ = Double(savingsGoal) {
            UserDefaults.standard.set(savingsGoal, forKey: "savingsGoal")
        } else {
            // If invalid, revert to the previous valid value
            savingsGoal = UserDefaults.standard.string(forKey: "savingsGoal") ?? "5000.00"
        }
    }
    
    private func saveSavingsDeadline() {
        UserDefaults.standard.set(savingsDeadline, forKey: "savingsDeadline")
    }
}

// Helper view for tips
struct TipView: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    // Need to set up an in-memory container for the preview
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: config)
        
        return PlanningView()
            .modelContainer(container)
    } catch {
        fatalError("Failed to create model container for preview: \(error.localizedDescription)")
    }
} 