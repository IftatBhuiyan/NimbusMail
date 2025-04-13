import SwiftUI
import SwiftData
import LinkKit

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
    
    // MARK: - Plaid Link State
    @State private var linkToken: String? = nil // To store the fetched link_token
    @State private var plaidHandler: Handler? = nil // To hold the Plaid handler instance
    @State private var isShowingPlaidLink = false // To trigger presentation (e.g., via .sheet)
    @State private var plaidError: Error? = nil // To store potential errors
    @State private var isLoadingLinkToken = false // Loading indicator state
    
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
                    LazyVStack(alignment: .leading, spacing: 25) { // Add spacing between sections
                        
                        // --- Monthly Budget Card --- 
                        SectionHeader(title: "Monthly Budget")
                        monthlyBudgetCard // Call computed property
                        
                        // --- Savings Goal Card --- 
                        SectionHeader(title: "Savings Goal")
                        savingsGoalCard // Call computed property
                        
                        // --- Account Linking Card ---
                        SectionHeader(title: "Account Linking")
                        accountLinkingCard // Call computed property
                        
                        // --- Financial Tips Section --- 
                        SectionHeader(title: "Financial Tips")
                        financialTipsSection // Call computed property
                        
                    } // End LazyVStack
                    .padding(.horizontal) // Horizontal padding for all cards
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
        .onAppear { // Load initial date correctly on appear
             let savedInterval = UserDefaults.standard.double(forKey: "savingsDeadlineInterval")
             // Ensure a valid date, defaulting if needed
             if savedInterval > 0 {
                 savingsDeadline = Date(timeIntervalSinceReferenceDate: savedInterval)
             } else {
                 // If nothing saved or invalid, set default and save it
                 let defaultDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
                 savingsDeadline = defaultDate
                 saveSavingsDeadline(date: defaultDate)
             }
         }
    }
    
    // MARK: - Computed View Properties for Body Clarity
    
    private var monthlyBudgetCard: some View {
        VStack(alignment: .leading, spacing: 15) { // Increased spacing inside card
            // Budget Amount Row
            HStack {
                Text("Budget:")
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                Spacer()
                if isEditingBudget {
                    TextField("Amount", text: $monthlyBudget)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(NeumorphicTextFieldStyle()) // Apply neumorphic text field style
                        .frame(width: 120)
                    Button("Save") {
                        // Basic validation before saving
                        if Double(monthlyBudget) != nil {
                            isEditingBudget = false
                            // @AppStorage handles saving automatically
                        } else {
                            // Revert to previous valid value if input is bad
                            monthlyBudget = UserDefaults.standard.string(forKey: "monthlyBudget") ?? "1000.00"
                        }
                    }
                    .buttonStyle(NeumorphicButtonStyle()) // Apply neumorphic button style
                } else {
                    Text(formatCurrency(Double(monthlyBudget) ?? 0))
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                    Button { isEditingBudget = true } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                    }
                    .tint(Color(hex: "0D2750").opacity(0.7)) // Control button tint
                }
            }

            // Progress Bar Area
            VStack(alignment: .leading, spacing: 5) {
                Text("Monthly Progress:")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "0D2750").opacity(0.7))

                NeumorphicProgressView(value: budgetProgress, color: progressColor)
                    .frame(height: 20)

                // Spent/Remaining Text
                HStack {
                    Text("Spent: \(formatCurrency(currentMonthSpending))")
                    Spacer()
                    if let budget = Double(monthlyBudget) {
                        Text("Remaining: \(formatCurrency(max(0, budget - currentMonthSpending))) ") // Ensure remaining isn't negative
                            .foregroundColor(budget < currentMonthSpending ? .red : Color(hex: "0D2750").opacity(0.7))
                    }
                }
                .font(.caption)
                .foregroundColor(Color(hex: "0D2750").opacity(0.7))
            }
        }
        .padding() // Padding inside the card
        .background(neumorphicCardBackground()) // Apply drop shadow card background
    }
    
    private var savingsGoalCard: some View {
        VStack(alignment: .leading, spacing: 15) { // Increased spacing inside card
            // Target Amount Row
            HStack {
                Text("Target Amount:")
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                Spacer()
                if isEditingSavings {
                    TextField("Goal", text: $savingsGoal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(NeumorphicTextFieldStyle()) // Apply neumorphic style
                        .frame(width: 120)
                    Button("Save") {
                        // Basic validation before saving
                        if Double(savingsGoal) != nil {
                            isEditingSavings = false
                            // @AppStorage handles saving automatically
                        } else {
                            savingsGoal = UserDefaults.standard.string(forKey: "savingsGoal") ?? "5000.00"
                        }
                    }
                    .buttonStyle(NeumorphicButtonStyle()) // Apply neumorphic style
                } else {
                    Text(formatCurrency(Double(savingsGoal) ?? 0))
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                    Button { isEditingSavings = true } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                    }
                    .tint(Color(hex: "0D2750").opacity(0.7))
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
                    .accentColor(Color(hex: "0D2750").opacity(0.8)) // Style DatePicker accent
                    // Consider adding a neumorphic background to DatePicker if possible/desired
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
        .padding() // Padding inside the card
        .background(neumorphicCardBackground()) // Apply drop shadow card background
    }
    
    // --- New Card for Account Linking ---
    private var accountLinkingCard: some View {
        VStack(spacing: 15) {
             if isLoadingLinkToken {
                 ProgressView() // Show loading indicator
                     .padding()
                     .frame(maxWidth: .infinity)
             } else {
                 Button {
                     Task {
                         await fetchLinkTokenAndOpenPlaid()
                     }
                 } label: {
                     Label("Link Bank Account", systemImage: "link.badge.plus")
                         .font(.headline)
                         .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                         .padding()
                         .frame(maxWidth: .infinity)
                 }
                 .buttonStyle(NeumorphicButtonStyle())
             }

             // Display error if any
             if let error = plaidError {
                 Text("Error: \(error.localizedDescription)")
                     .font(.caption)
                     .foregroundColor(.red)
                     .padding(.top, 5)
             }
        }
        .padding()
        .background(neumorphicCardBackground()) // Apply drop shadow card background
        // --- Use .sheet for Plaid Link Presentation ---
        .sheet(isPresented: $isShowingPlaidLink) {
            if let handler = plaidHandler {
                 PlaidLinkViewRepresentable(handler: handler, isPresented: $isShowingPlaidLink)
            } else {
                 // Handle case where sheet is shown but handler is nil (should not happen ideally)
                 Text("Error: Plaid handler not available.")
            }
        }
    }
    
    private var financialTipsSection: some View {
         // Use a VStack to group the tip cards with consistent spacing
         VStack(spacing: 15) { 
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
         }
    }
    
    // Helper function to create the neumorphic card background (Drop Shadow 2)
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
    
    // MARK: - Plaid Link Functions
    
    private func fetchLinkTokenAndOpenPlaid() async {
        isLoadingLinkToken = true
        plaidError = nil
        
        // --- 1. Fetch Link Token from Your Backend --- 
        // This requires a network call to your server endpoint
        // Replace with your actual network request logic
        do {
            // Example: let fetchedToken = try await YourAPIService.shared.fetchLinkToken()
            // --- Placeholder --- 
            print("TODO: Fetch link_token from backend...")
            // Simulate network delay and success
            try await Task.sleep(nanoseconds: 1_500_000_000) 
            let fetchedToken = "link-sandbox-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" // Replace with actual fetched token
            // --- End Placeholder ---
            self.linkToken = fetchedToken
            
            // --- 2. Create Link Configuration --- 
            guard let token = self.linkToken else {
                throw PlaidLinkError.missingLinkToken // Define this error type if needed
            }

            let onSuccess: (LinkSuccess) -> Void = { success in
                print("Plaid Link Success: public_token=\(success.publicToken) metadata=\(success.metadata)")
                // TODO: Send success.publicToken to your backend
                // Example: sendPublicTokenToServer(success.publicToken)
                self.isShowingPlaidLink = false // Dismiss sheet on success
                self.plaidHandler = nil
            }

            var linkConfiguration = LinkTokenConfiguration(
                token: token,
                onSuccess: onSuccess
            )

            linkConfiguration.onExit = { linkExit in
                self.isShowingPlaidLink = false // Dismiss sheet on exit
                self.plaidHandler = nil
                if let error = linkExit.error {
                    print("Plaid Link Exit with error: \(error.localizedDescription) metadata: \(linkExit.metadata)")
                    self.plaidError = error
                } else {
                    print("Plaid Link Exit (no error): metadata: \(linkExit.metadata)")
                }
            }

            linkConfiguration.onEvent = { linkEvent in
                print("Plaid Link Event: \(linkEvent.eventName) metadata: \(linkEvent.metadata)")
            }
            
            // --- 3. Create Plaid Handler ---
            // Plaid.create returns a Result, not throwing directly
            let createResult = Plaid.create(linkConfiguration)
            switch createResult {
            case .success(let handler):
                self.plaidHandler = handler
            case .failure(let error):
                throw error // Re-throw the specific Plaid.CreateError
            }
            
            // --- 4. Trigger Sheet Presentation --- 
            self.isShowingPlaidLink = true // This will show the .sheet
            // The actual .open() call needs to happen within the sheet's content (e.g., via representable)

        } catch {
            print("Error during Plaid Link setup: \(error)")
            self.plaidError = error
            self.plaidHandler = nil
        }
        
        isLoadingLinkToken = false
    }
}

// MARK: - Plaid Link View Representable

import LinkKit

struct PlaidLinkViewRepresentable: UIViewControllerRepresentable {
    let handler: Handler
    @Binding var isPresented: Bool // Add binding to control sheet dismissal

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        // Present Plaid Link immediately when the representable appears
        // Use .viewController presentation style, passing the host VC
        // The completion handler is not used with this presentation method.
        handler.open(presentUsing: .viewController(viewController))
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No update needed for this simple case
    }
}

// MARK: - Placeholder Error Type

enum PlaidLinkError: Error, LocalizedError {
    case missingLinkToken
    case handlerCreationFailed
    // Add other potential error cases

    var errorDescription: String? {
        switch self {
        case .missingLinkToken: return "Link token is missing."
        case .handlerCreationFailed: return "Failed to create Plaid Handler."
        }
    }
}

// MARK: - Preview

#Preview {
    // Need to set up an in-memory container for the preview
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: config)
        
        // Add some sample transactions if needed for preview calculation
        let sampleTransaction = Transaction(merchant: "Coffee Shop", bank: "Preview Bank", amount: 4.50, date: Date())
        container.mainContext.insert(sampleTransaction)

        return PlanningView()
            .modelContainer(container)
    } catch {
        fatalError("Failed to create model container for preview: \(error.localizedDescription)")
    }
} 