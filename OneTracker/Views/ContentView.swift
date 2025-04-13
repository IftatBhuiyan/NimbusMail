//
//  ContentView.swift
//  OneTracker
//
//  Created by Iftat Bhuiyan on 4/8/25.
//

import SwiftUI
import SwiftData

// Enum to manage sheet presentation state
enum ActiveSheet: Identifiable {
    case add
    case edit(Transaction)
    case profile

    // Use AnyHashable for the ID type to accommodate String and PersistentIdentifier
    var id: AnyHashable {
        switch self {
        case .add: return "add" // String conforms to Hashable
        case .edit(let transaction): return transaction.id // PersistentIdentifier conforms to Hashable
        case .profile: return "profile"
        }
    }
}

// Enum for time period selection
enum TimePeriod: Hashable {
    case daily
    case weekly
    case monthly
    case custom(DateInterval)
    case all
    
    // Add back the display name computed property
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom Range"
        case .all: return "All Time"
        }
    }
}

// Main Content View (Acts as Finances View in this structure)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var activeSheet: ActiveSheet? = nil
    @State private var selectedPeriod: TimePeriod = .all // Default to All instead of monthly
    @State private var showingPeriodSelector = false // State to show selector sheet
    @State private var isShowingRecurringOnly = false // Track if we're showing just recurring transactions
    @EnvironmentObject var viewModel: UserViewModel // Add EnvironmentObject

    // Computed property for unique merchant names
    private var uniqueMerchantNames: [String] {
        // Combine common names and user's names, remove duplicates, sort
        let userNames = transactions.map { $0.merchant }
        let combined = Set(SuggestionData.commonMerchants + userNames)
        return combined.sorted()
    }

    // Computed property for unique bank names
    private var uniqueBankNames: [String] {
        // Combine common names and user's names, remove duplicates, sort
        let userNames = transactions.map { $0.bank }
        let combined = Set(SuggestionData.commonBanks + userNames)
        return combined.sorted()
    }

    // Computed property for title text based on current mode
    private var titleText: String {
        return isShowingRecurringOnly ? "Subscriptions" : "Finances"
    }

    // Renamed and updated computed property for selected period's total
    private var selectedPeriodTotalString: String {
        let interval: DateInterval?

        // Determine the date interval based on the selected period
        switch selectedPeriod {
        case .daily:
            guard let dayInterval = Calendar.current.dateInterval(of: .day, for: Date()) else { return "$0.00" }
            interval = dayInterval
        case .weekly:
            guard let weekInterval = Calendar.current.dateInterval(of: .weekOfMonth, for: Date()) else { return "$0.00" }
            interval = weekInterval
        case .monthly:
            guard let monthInterval = Calendar.current.dateInterval(of: .month, for: Date()) else { return "$0.00" }
            interval = monthInterval
        case .custom(let customInterval):
            interval = customInterval
        case .all:
            // No interval filtering for "all" - we'll use nil to indicate all transactions
            interval = nil
        }

        // Calculate total based on the interval (if any)
        let periodTotal: Double
        if let interval = interval {
            // Filter by date range if interval is provided
            periodTotal = transactions
                .filter { interval.contains($0.date) }
                .reduce(0) { $0 + $1.amount }
        } else {
            // Sum all transactions if no interval (all-time)
            periodTotal = transactions.reduce(0) { $0 + $1.amount }
        }

        // Format as currency and add negative sign
        let formatted = periodTotal.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        return "-" + formatted
    }

    // Computed property for the toolbar title (e.g., "Monthly Total")
    private var toolbarTitle: String {
        switch selectedPeriod {
        case .daily: return "Daily Total"
        case .weekly: return "Weekly Total"
        case .monthly: return "Monthly Total"
        case .custom: return "Custom Total"
        case .all: return "All-Time Total"
        }
    }

    // Group transactions directly from the @Query results
    var groupedTransactions: [String: [Transaction]] {
        // First, filter transactions based on the selected period
        var filteredTransactions: [Transaction]
        
        switch selectedPeriod {
        case .daily:
            guard let dayInterval = Calendar.current.dateInterval(of: .day, for: Date()) else {
                filteredTransactions = []
                break
            }
            filteredTransactions = transactions.filter { dayInterval.contains($0.date) }
            
        case .weekly:
            guard let weekInterval = Calendar.current.dateInterval(of: .weekOfMonth, for: Date()) else {
                filteredTransactions = []
                break
            }
            filteredTransactions = transactions.filter { weekInterval.contains($0.date) }
            
        case .monthly:
            guard let monthInterval = Calendar.current.dateInterval(of: .month, for: Date()) else {
                filteredTransactions = []
                break
            }
            filteredTransactions = transactions.filter { monthInterval.contains($0.date) }
            
        case .custom(let interval):
            filteredTransactions = transactions.filter { interval.contains($0.date) }
            
        case .all:
            // Show all transactions
            filteredTransactions = transactions
        }
        
        // Apply recurring filter if in subscription view mode
        if isShowingRecurringOnly {
            filteredTransactions = filteredTransactions.filter { $0.frequency == .recurring }
        }
        
        // Then group the filtered transactions by date
        return Dictionary(grouping: filteredTransactions) { transaction -> String in
            if Calendar.current.isDateInToday(transaction.date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(transaction.date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d" // e.g., Apr 7
                return formatter.string(from: transaction.date)
            }
        }
    }

    // Define the order of the sections based on the grouped keys
    var sectionOrder: [String] {
        // No need for today/yesterday vars here anymore
        return groupedTransactions.keys.sorted { key1, key2 in
            if key1 == "Today" { return true }
            if key2 == "Today" { return false }
            if key1 == "Yesterday" { return true }
            if key2 == "Yesterday" { return false }

            // Compare older dates using a formatter that includes the year for proper sorting across years
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d yyyy" // Use year for robust sorting
            guard let date1 = formatter.date(from: key1 + " " + String(Calendar.current.component(.year, from: Date()))), // Append year heuristically
                  let date2 = formatter.date(from: key2 + " " + String(Calendar.current.component(.year, from: Date()))) else {

                // Fallback if date parsing fails (e.g., unexpected key format)
                // Try parsing just "MMM d" again, assuming same year
                 formatter.dateFormat = "MMM d"
                 guard let simpleDate1 = formatter.date(from: key1), let simpleDate2 = formatter.date(from: key2) else {
                     return false // Cannot determine order if parsing fails completely
                 }
                 // Add current year component for comparison
                 let currentYear = Calendar.current.component(.year, from: Date())
                 let comp1 = Calendar.current.dateComponents([.month, .day], from: simpleDate1)
                 let comp2 = Calendar.current.dateComponents([.month, .day], from: simpleDate2)
                 guard let finalDate1 = Calendar.current.date(from: DateComponents(year: currentYear, month: comp1.month, day: comp1.day)),
                       let finalDate2 = Calendar.current.date(from: DateComponents(year: currentYear, month: comp2.month, day: comp2.day)) else {
                     return false
                 }
                 return finalDate1 > finalDate2
            }
            return date1 > date2 // Most recent date first
        }
    }

    var body: some View {
        TabView {
            // Finances Tab
            NavigationView {
                ZStack(alignment: .bottomTrailing) { // ZStack for content and FAB
                    // Neumorphic Background Color
                    neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)

                    // Main Content VStack - Apply Inner Shadow (Shadow 4)
                    VStack(spacing: 0) {
                        // Fixed header
                        HStack {
                            // Make the title tappable
                            Button {
                                withAnimation {
                                    isShowingRecurringOnly.toggle()
                                }
                            } label: {
                                Text(titleText)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic text color
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(alignment: .trailing) {
                                Text(toolbarTitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // Make the total tappable to open period selector
                                Button {
                                    showingPeriodSelector = true
                                } label: {
                                    Text(selectedPeriodTotalString)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.blue) // Highlight the total
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding([.horizontal, .top])
                        .padding(.bottom, 8) // Reduced bottom padding
                        // Removed header background: .background(Color(UIColor.systemBackground))

                        // Conditional view for empty state or list
                        if groupedTransactions.isEmpty { // Use groupedTransactions to reflect filters
                            ContentUnavailableView(
                                isShowingRecurringOnly ? "No Subscriptions" : "No Transactions",
                                systemImage: isShowingRecurringOnly ? "repeat.circle" : "list.bullet.rectangle.portrait",
                                description: Text(isShowingRecurringOnly ? "No recurring transactions found for the selected period." : "Tap the + button to add your first transaction.")
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow empty view to expand
                            .background(neumorphicBackgroundColor) // Match background
                        } else {
                            // --- Use ScrollView + LazyVStack with Pinned Section Headers --- 
                            ScrollView {
                                // Enable pinned section headers
                                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                                    ForEach(sectionOrder, id: \.self) { dateKey in
                                        // Wrap each date group in a Section
                                        Section {
                                            // Transaction Cards for this section (The content of the section)
                                            // Add spacing between cards within the section using VStack
                                            VStack(spacing: 15) { 
                                                ForEach(groupedTransactions[dateKey] ?? []) { transaction in
                                                    // Button wraps the styled content
                                                    Button {
                                                        activeSheet = .edit(transaction)
                                                    } label: {
                                                        // Break down the complex nested expression
                                                        let rowContent = TransactionRow(transaction: transaction)
                                                            .padding() // Padding inside the background
                                                        
                                                        // Create the background separately
                                                        let backgroundShape = RoundedRectangle(cornerRadius: 10)
                                                            .fill(neumorphicBackgroundColor)
                                                        
                                                        // Apply shadows separately
                                                        let shadowedBackground = backgroundShape
                                                            .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
                                                            .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
                                                        
                                                        // Combine them
                                                        rowContent
                                                            .background(shadowedBackground)
                                                    } // End Button Label
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.bottom, 15) // Add padding below the last card in a section

                                        } header: {
                                            // Section Header Content
                                            Text(dateKey)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                                                .padding(.leading) // Align with card content
                                                .padding(.vertical, 8) // Adjusted vertical padding for header
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        // Removed delete functionality here, needs reimplementation if required outside of List
                                    }
                                } // End ForEach sectionOrder
                                .padding(.horizontal) // Padding for the cards within the scroll view
                                // .padding(.bottom) // Bottom padding handled by VStack spacing or ScrollView itself
                            } // End ScrollView
                        }
                    } // End Main Content VStack
                     .background( // Apply Inner Shadow (Shadow 4) to the VStack content
                         RoundedRectangle(cornerRadius: 20)
                             .fill(neumorphicBackgroundColor)
                             .shadow(color: darkInnerShadowColor, radius: darkInnerShadowBlur, x: darkInnerShadowX, y: darkInnerShadowY)
                             .shadow(color: lightInnerShadowColor, radius: lightInnerShadowBlur, x: lightInnerShadowX, y: lightInnerShadowY)
                     )
                     .clipShape(RoundedRectangle(cornerRadius: 20))
                     .padding() // Padding around the inner-shadowed area
                    .navigationBarHidden(true) // Keep hiding the default nav bar

                    // Floating Action Button - Apply Drop Shadow (Shadow 2)
                    Button(action: {
                        activeSheet = .add
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic icon color
                            .frame(width: 60, height: 60) // Fixed size
                            .background(
                                Circle()
                                    .fill(neumorphicBackgroundColor)
                                    .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur, x: darkDropShadowX, y: darkDropShadowY)
                                    .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur, x: lightDropShadowX, y: lightDropShadowY)
                            )
                           // Removed old styling
                    }
                    .padding() // Padding from edges
                    .padding(.bottom, 20) // Adjusted bottom padding
                    .padding(.trailing, 10) // Adjusted right padding

                } // End ZStack
                // Sheet for adding/editing transactions
                .sheet(item: $activeSheet) { item in
                    switch item {
                    case .add:
                        AddTransactionView(
                            allMerchantNames: uniqueMerchantNames,
                            allBankNames: uniqueBankNames,
                            onSave: { formData in
                                addTransaction(formData: formData)
                                activeSheet = nil
                            }
                        )
                    case .edit(let transaction):
                        AddTransactionView(
                            transactionToEdit: transaction,
                            allMerchantNames: uniqueMerchantNames,
                            allBankNames: uniqueBankNames,
                            onSave: { formData in
                                updateTransaction(transaction, with: formData)
                                activeSheet = nil
                            }
                        )
                    case .profile:
                        ProfileView(viewModel: viewModel)
                    }
                }
                 // Sheet for selecting period
                .sheet(isPresented: $showingPeriodSelector) {
                    PeriodSelectorView(selectedPeriod: $selectedPeriod)
                        .presentationDetents([.medium]) // Use medium height
                         .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)) // Style sheet background
                }
                .toolbarRole(.editor) // Keep toolbar role if needed
            }
            .tabItem {
                Label("Finance", systemImage: "creditcard.fill") // Use filled icon when selected
            }

            // Planning Tab
            PlanningView()
                .tabItem {
                    Label("Planning", systemImage: "chart.bar.fill")
                }

            // Fitness Tab
            FitnessView()
                .tabItem {
                    Label("Fitness", systemImage: "figure.run")
                }

            // Health Tab
            HealthView()
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }

            // Profile Tab (New)
            NavigationView { // Wrap ProfileView in NavigationView for title bar
                 ProfileView(viewModel: viewModel)
                    .navigationTitle("Profile") // Add a title
                    .environmentObject(viewModel) // Ensure viewModel is available
            }
            .tabItem {
                 Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
         .accentColor(.blue) // Keep accent color for selected tab
    }

    // Update addTransaction to take formData and include new fields
    private func addTransaction(formData: TransactionFormData) {
         withAnimation {
            let newTransaction = Transaction(merchant: formData.merchant,
                                           bank: formData.bank,
                                           amount: formData.amount,
                                           date: formData.date,
                                           frequency: formData.frequency,
                                           recurringEndDate: formData.recurringEndDate)
            modelContext.insert(newTransaction)
         }
    }

    // Update updateTransaction to include new fields
    private func updateTransaction(_ transaction: Transaction, with formData: TransactionFormData) {
        withAnimation {
            transaction.merchant = formData.merchant
            transaction.bank = formData.bank
            transaction.amount = formData.amount
            transaction.date = formData.date // This is the start date if recurring
            transaction.frequency = formData.frequency
            transaction.recurringEndDate = formData.recurringEndDate
        }
    }

    // Add function to delete items using ModelContext
    private func deleteItems(forDateKey dateKey: String, offsets: IndexSet) {
         guard let transactionsForDate = groupedTransactions[dateKey] else { return }

         withAnimation { // Optional: Animate deletion
            for index in offsets {
                let transactionToDelete = transactionsForDate[index]
                modelContext.delete(transactionToDelete)
            }
        }
    }
}

// Custom view for a single transaction row
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(transaction.merchant)
                        .font(.headline)
                         .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic text color
                    if transaction.frequency == .recurring {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Text(transaction.bank)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("-\(transaction.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))") // Use currency formatting
                .font(.body)
                 .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Neumorphic text color
        }
        // Removed padding here, it's applied outside now
    }
}

#Preview {
    // Need to set up an in-memory container for the preview
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Transaction.self, configurations: config)

        // Optional: Add sample data to the preview container
        let sampleData = [
             Transaction(merchant: "Preview McD", bank: "Chase", amount: 10.99, date: Date()),
             Transaction(merchant: "Preview WF", bank: "Wells Fargo", amount: 55.50, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        ]
        sampleData.forEach { container.mainContext.insert($0) }

        return ContentView()
            .modelContainer(container)
    } catch {
        fatalError("Failed to create model container for preview: \(error.localizedDescription)")
    }
}

