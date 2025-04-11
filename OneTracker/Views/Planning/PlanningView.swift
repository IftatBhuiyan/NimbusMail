import SwiftUI
import SwiftData

struct PlanningView: View {
    // State variables for budgets and goals
    @AppStorage("monthlyBudget") private var monthlyBudget: String = "1000.00"
    @AppStorage("savingsGoal") private var savingsGoal: String = "5000.00"
    // Use AppStorage for Date requires transformation (e.g., TimeInterval)
    @State private var savingsDeadline: Date = Date(timeIntervalSinceReferenceDate: UserDefaults.standard.double(forKey: "savingsDeadlineInterval"))
    
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
        ZStack {
            // Background Color
            neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)

            // Main Content Container with Inner Shadow
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Text("Planning")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic Text Color
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                    
                    // Reset button
                    Button {
                        // Reset budget and spent values to default
                        monthlyBudget = "1000.00"
                        savingsGoal = "5000.00"
                        let defaultDeadline = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
                        savingsDeadline = defaultDeadline
                        saveSavingsDeadline(date: defaultDeadline) // Explicitly save default date
                        isEditingBudget = false
                        isEditingSavings = false
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic Icon Color
                            .padding()
                    }
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 15) // Increased padding
                // Removed background: .background(Color(UIColor.systemBackground))
                
                // Content Scroll Area
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) { // Add spacing for sections
                        
                        // --- Monthly Budget Card --- 
                        SectionHeader(title: "Monthly Budget")
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Budget Amount Row
                            HStack {
                                Text("Budget:")
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                Spacer()
                                if isEditingBudget {
                                    TextField("Amount", text: $monthlyBudget)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(.plain)
                                        .padding(8)
                                        .background(neumorphicBackgroundColor.opacity(0.5).cornerRadius(5))
                                        .frame(width: 120)
                                    Button("Save") {
                                        // Basic validation
                                        if Double(monthlyBudget) != nil { 
                                            isEditingBudget = false
                                        } else {
                                            // Handle invalid input (e.g., alert)
                                            monthlyBudget = "1000.00" // Revert or show error
                                        }
                                    }
                                    .buttonStyle(NeumorphicButtonStyle(isPressed: false))
                                    .padding(.leading, 5)
                                } else {
                                    Text(formatCurrency(Double(monthlyBudget) ?? 0))
                                        .fontWeight(.medium)
                                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                    Button {
                                        isEditingBudget = true
                                    } label: {
                                        Image(systemName: "pencil.circle")
                                             .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                                    }
                                }
                            }
                            
                            // Progress Bar Area
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Monthly Progress:")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background Track
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(neumorphicBackgroundColor)
                                            .shadow(color: darkInnerShadowColor, radius: 2, x: 1, y: 1) // Subtle inner shadow
                                            .shadow(color: lightInnerShadowColor, radius: 2, x: -1, y: -1)
                                            .frame(height: 20)
                                        
                                        // Progress Fill
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(progressColor)
                                            .frame(width: max(0, geometry.size.width * budgetProgress), height: 20)
                                            .animation(.spring(), value: budgetProgress)
                                            .shadow(color: darkDropShadowColor.opacity(0.1), radius: 3, x: 2, y: 2) // Subtle drop shadow on progress
                                    }
                                }
                                .frame(height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5)) // Clip shadows to bar shape
                                
                                // Spent/Remaining Text
                                HStack {
                                    Text("Spent: \(formatCurrency(currentMonthSpending))")
                                    Spacer()
                                    if let budget = Double(monthlyBudget) {
                                        Text("Remaining: \(formatCurrency(max(budget - currentMonthSpending, 0)))")
                                            .foregroundColor(budget < currentMonthSpending ? .red : Color(hex: "0D2750").opacity(0.7))
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                            }
                        }
                        .padding()
                        .background(neumorphicCardBackground())
                        
                        // --- Savings Goal Card --- 
                        SectionHeader(title: "Savings Goal")
                        
                        VStack(alignment: .leading, spacing: 10) {
                             // Target Amount Row
                            HStack {
                                Text("Target Amount:")
                                     .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                Spacer()
                                if isEditingSavings {
                                    TextField("Goal", text: $savingsGoal)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(.plain)
                                        .padding(8)
                                        .background(neumorphicBackgroundColor.opacity(0.5).cornerRadius(5))
                                        .frame(width: 120)
                                    Button("Save") {
                                        // Basic validation
                                        if Double(savingsGoal) != nil {
                                            isEditingSavings = false
                                        } else {
                                            savingsGoal = "5000.00" // Revert or show error
                                        }
                                    }
                                     .buttonStyle(NeumorphicButtonStyle(isPressed: false))
                                     .padding(.leading, 5)
                                } else {
                                    Text(formatCurrency(Double(savingsGoal) ?? 0))
                                        .fontWeight(.medium)
                                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                    Button {
                                        isEditingSavings = true
                                    } label: {
                                        Image(systemName: "pencil.circle")
                                             .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                                    }
                                }
                            }
                            
                            // Target Date Row
                            HStack {
                                Text("Target Date:")
                                     .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                Spacer()
                                DatePicker("", selection: $savingsDeadline, displayedComponents: .date)
                                    .labelsHidden()
                                    .onChange(of: savingsDeadline) { _, newDate in saveSavingsDeadline(date: newDate) }
                                    .accentColor(Color(hex: "0D2750").opacity(0.8))
                            }
                            
                            // Monthly Savings Needed Row
                            if let goalAmount = Double(savingsGoal), goalAmount > 0 {
                                let months = max(Calendar.current.dateComponents([.month], from: Date(), to: savingsDeadline).month ?? 1, 1)
                                let monthlySavingsNeeded = goalAmount / Double(months)
                                
                                HStack {
                                    Text("Monthly savings needed:")
                                         .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                    Spacer()
                                    Text(formatCurrency(monthlySavingsNeeded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                }
                            }
                        }
                        .padding()
                        .background(neumorphicCardBackground())
                        
                        // --- Financial Tips Section --- 
                        SectionHeader(title: "Financial Tips")
                        
                        // Tip Cards
                        TipView(title: "50/30/20 Rule", 
                               description: "Try to allocate 50% of your budget to needs, 30% to wants, and 20% to savings.")
                            .padding()
                            .background(neumorphicCardBackground())
                        
                        TipView(title: "Track Recurring Expenses", 
                               description: "Review your subscriptions regularly to avoid unnecessary recurring charges.")
                            .padding()
                            .background(neumorphicCardBackground())
                        
                        TipView(title: "Emergency Fund", 
                               description: "Aim to save 3-6 months of expenses for emergencies.")
                            .padding()
                            .background(neumorphicCardBackground())
                        
                    } // End LazyVStack
                    .padding(.horizontal) // Padding for the cards
                    .padding(.bottom) // Bottom padding for scroll content
                } // End ScrollView
            } // End Main Content VStack
            .background( // Apply Inner Shadow (Shadow 4) to the VStack content
                 RoundedRectangle(cornerRadius: 20)
                     .fill(neumorphicBackgroundColor)
                     .shadow(color: darkInnerShadowColor, radius: darkInnerShadowBlur, x: darkInnerShadowX, y: darkInnerShadowY)
                     .shadow(color: lightInnerShadowColor, radius: lightInnerShadowBlur, x: lightInnerShadowX, y: lightInnerShadowY)
             )
             .clipShape(RoundedRectangle(cornerRadius: 20))
             .padding() // Padding around the inner-shadowed area
        } // End ZStack
        .onAppear { // Load initial date correctly
             let savedInterval = UserDefaults.standard.double(forKey: "savingsDeadlineInterval")
             // Ensure a valid date, defaulting if needed
             savingsDeadline = savedInterval > 0 ? Date(timeIntervalSinceReferenceDate: savedInterval) : Calendar.current.date(byAdding: .month, value: 6, to: Date())! 
         }
    }
    
    // Helper function to create the neumorphic card background
    @ViewBuilder
    private func neumorphicCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(neumorphicBackgroundColor)
            .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
            .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
    
    // Save Deadline Date to UserDefaults as TimeInterval
    private func saveSavingsDeadline(date: Date) {
        UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: "savingsDeadlineInterval")
    }
}

// MARK: - Helper Views

// Simple Text Header for Sections
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "0D2750").opacity(0.7))
            .padding(.leading) // Align with card content
            .padding(.top, 10)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Tip View (Already defined, adjust colors if needed)
struct TipView: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                 .foregroundColor(Color(hex: "0D2750").opacity(0.8))
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        // Padding applied by the caller now
    }
}

// Custom Button Style for Neumorphism
struct NeumorphicButtonStyle: ButtonStyle {
    var isPressed: Bool // You might pass this in if tracking press state
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(neumorphicBackgroundColor)
                    // Apply opposite shadows when pressed
                    .shadow(color: configuration.isPressed ? lightDropShadowColor : darkDropShadowColor, radius: 5, x: configuration.isPressed ? -3 : 3, y: configuration.isPressed ? -3 : 3)
                    .shadow(color: configuration.isPressed ? darkDropShadowColor : lightDropShadowColor, radius: 5, x: configuration.isPressed ? 3 : -3, y: configuration.isPressed ? 3 : -3)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .foregroundColor(Color(hex: "0D2750").opacity(0.8))
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


// MARK: - Preview

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