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

    // Conformance to Identifiable - use AnyHashable
    var id: AnyHashable {
        switch self {
        case .add: return "add"
        case .edit(let transaction): return transaction.persistentModelID // Use SwiftData's persistent ID
        }
    }
}

// Enum for selecting the time period
enum TimePeriod: Equatable {
    case daily
    case weekly
    case monthly
    case all // Add all-time option
    case custom(DateInterval)

    // Basic display name
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .all: return "All" // Add display name
        case .custom: return "Custom Range"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var activeSheet: ActiveSheet? = nil
    @State private var selectedPeriod: TimePeriod = .all // Default to All instead of monthly
    @State private var showingPeriodSelector = false // State to show selector sheet
    @State private var isShowingRecurringOnly = false // Track if we're showing just recurring transactions

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
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    // Use conditional view for empty state
                     if transactions.isEmpty {
                         ContentUnavailableView("No Transactions", systemImage: "list.bullet.rectangle.portrait", description: Text("Tap the + button to add your first transaction."))
                     } else {
                        VStack(spacing: 0) { // Container for fixed header and scrolling list
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
                                }
                                Spacer()
                                Button {
                                    showingPeriodSelector = true
                                } label: {
                                    VStack(alignment: .trailing) {
                                        Text(toolbarTitle)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(selectedPeriodTotalString)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .tint(.primary)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            .padding(.bottom, 10)
                            .background(Color(UIColor.systemBackground)) // Match the background color

            List {
                                // Remove the custom header section
                                // The date-grouped sections remain unchanged
                                ForEach(sectionOrder, id: \.self) { dateKey in
                                    Section(header: VStack(alignment: .leading, spacing: 4) {
                                        Text(dateKey)
                                            .font(.title3)
                                            .fontWeight(.medium)
                                        Divider()
                                    }) {
                                        // Iterate over the correct group from the dictionary
                                        ForEach(groupedTransactions[dateKey] ?? []) { transaction in
                                            TransactionRow(transaction: transaction)
                                                .listRowSeparator(.hidden)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    activeSheet = .edit(transaction)
                                                }
                                        }
                                        .onDelete { indexSet in
                                            deleteItems(forDateKey: dateKey, offsets: indexSet)
                                        }
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                            // Remove extra padding at the top of the list
                            .scrollContentBackground(.hidden)
                            .padding(.top, 0)
                        }
                        // Use .navigationBarHidden to hide the standard title
                        .navigationBarHidden(true)
                    }

                    // Floating Action Button
                    Button(action: {
                        // Set activeSheet to .add
                        activeSheet = .add
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding() // Add padding from the edges
                    .padding(.bottom, 20) // Adjusted bottom padding (as per previous step)
                    .padding(.trailing, 10) // Adjusted right padding (as per previous step)
                    // Use .sheet(item: ...) modifier
                    .sheet(item: $activeSheet) { sheetState in // sheetState is the non-nil ActiveSheet value
                        // Determine transaction to edit based on sheetState
                        let transactionForSheet: Transaction? = {
                            if case .edit(let transaction) = sheetState {
                                return transaction
                            } else {
                                return nil // It's the .add case
                            }
                        }()

                        // Present AddTransactionView, passing the optional transaction
                        AddTransactionView(transactionToEdit: transactionForSheet,
                                           allMerchantNames: uniqueMerchantNames,
                                           allBankNames: uniqueBankNames,
                                           onSave: { formData in
                            // Save logic remains similar, but uses transactionForSheet
                            if let existingTransaction = transactionForSheet {
                                updateTransaction(existingTransaction, with: formData)
                            } else {
                                addTransaction(formData: formData)
                            }
                            // No need to manually set activeSheet = nil, sheet(item:) handles dismiss
                        })
                        .presentationDetents([.medium, .large])
                    }
                    // Add sheet for period selector
                    .sheet(isPresented: $showingPeriodSelector) {
                        PeriodSelectorView(selectedPeriod: $selectedPeriod)
                            .presentationDetents([.medium]) // Show selector at medium height
                    }
                }
                .toolbarRole(.editor)
            }
            .tabItem {
                Label("Finance", systemImage: "creditcard.fill") // Use filled icon when selected
            }

            PlanningView()
                .tabItem {
                    Label("Planning", systemImage: "chart.bar.fill")
                }

            FitnessView()
                .tabItem {
                    Label("Fitness", systemImage: "figure.run")
                }

            HealthView()
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }
        }
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
                // Wrap merchant name and potential icon in an HStack
                HStack {
                    Text(transaction.merchant)
                        .font(.headline)
                    // Conditionally show recurring icon
                    if transaction.frequency == .recurring {
                        Image(systemName: "repeat")
                            .font(.caption) // Make icon smaller
                            .foregroundColor(.gray) // Style the icon
                    }
                }
                Text(transaction.bank)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer() // Pushes amount to the right
            // Modified to show negative amount (expense)
            Text("-" + String(format: "$%.2f", transaction.amount))
                .font(.body)
        }
        .padding(.vertical, 4) // Add some vertical padding to each row
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
