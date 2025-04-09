import SwiftUI

// Define a simple struct to hold the form data
struct TransactionFormData {
    var merchant: String
    var bank: String
    var amount: Double
    var date: Date // Start/Transaction Date
    var frequency: Frequency
    var recurringEndDate: Date? // Optional End Date
}

struct AddTransactionView: View {
    // Environment variable to dismiss the sheet
    @Environment(\.dismiss) var dismiss

    // State variables for form input
    @State private var merchantName: String = ""
    @State private var bankName: String = ""
    @State private var amountString: String = ""
    @State private var transactionDate: Date = Date() // Acts as start date for recurring
    @State private var selectedFrequency: Frequency = .oneTime
    @State private var recurringEndDate: Date? = nil
    @State private var hasEndDate: Bool = false // Toggle for optional end date

    // Properties to hold suggestion lists
    let allMerchantNames: [String]
    let allBankNames: [String]
    @State private var filteredMerchantNames: [String] = []
    @State private var filteredBankNames: [String] = []

    // Optional transaction to edit
    var transactionToEdit: Transaction?

    // Change the callback closure to pass TransactionFormData
    var onSave: (TransactionFormData) -> Void

    // Focus state management
    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case merchant, bank, amount
    }

    // Update the explicit initializer to accept optional transaction and suggestions
    internal init(transactionToEdit: Transaction? = nil,
                  allMerchantNames: [String] = [], // Add params for suggestions
                  allBankNames: [String] = [],
                  onSave: @escaping (TransactionFormData) -> Void)
    {
        self.transactionToEdit = transactionToEdit
        self.allMerchantNames = allMerchantNames
        self.allBankNames = allBankNames
        self.onSave = onSave

        // Initialize state based on transactionToEdit if provided
        if let transaction = transactionToEdit {
            _merchantName = State(initialValue: transaction.merchant)
            _bankName = State(initialValue: transaction.bank)
            _amountString = State(initialValue: String(format: "%.2f", transaction.amount))
            _transactionDate = State(initialValue: transaction.date)
            _selectedFrequency = State(initialValue: transaction.frequency)
            _recurringEndDate = State(initialValue: transaction.recurringEndDate)
            _hasEndDate = State(initialValue: transaction.recurringEndDate != nil)
        } else {
            // Defaults for adding new
            _merchantName = State(initialValue: "")
            _bankName = State(initialValue: "")
            _amountString = State(initialValue: "")
            _transactionDate = State(initialValue: Date())
            _selectedFrequency = State(initialValue: .oneTime)
            _recurringEndDate = State(initialValue: nil)
            _hasEndDate = State(initialValue: false)
        }
    }

    // Formatter for currency input
    private var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        NavigationView {
            Form {
                // Use Sections for potentially better grouping (optional)
                Section("Transaction Details") {
                    VStack(alignment: .leading) { // Use VStack to stack TextField and suggestions
                        Label {
                            TextField("Merchant Name", text: $merchantName)
                                .focused($focusedField, equals: .merchant)
                                .onChange(of: merchantName) { oldValue, newValue in
                                    filterMerchantSuggestions(newValue: newValue)
                                }
                        } icon: {
                            Image(systemName: "storefront") // Icon for merchant
                        }

                        // Display merchant suggestions
                        if focusedField == .merchant && !filteredMerchantNames.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(filteredMerchantNames, id: \.self) { name in
                                        Button(name) {
                                            merchantName = name
                                            filteredMerchantNames = [] // Clear suggestions
                                            focusedField = nil // Dismiss keyboard
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.gray)
                                    }
                                }
                                .padding(.leading, 40) // Indent suggestions under the icon/label
                            }
                            .frame(height: 40)
                        }
                    }

                    VStack(alignment: .leading) { // Use VStack for Bank suggestions
                        Label {
                            TextField("Bank Name", text: $bankName)
                                .focused($focusedField, equals: .bank)
                                .onChange(of: bankName) { oldValue, newValue in
                                    filterBankSuggestions(newValue: newValue)
                                }
                        } icon: {
                            Image(systemName: "building.columns") // Icon for bank
                        }

                        // Display bank suggestions
                        if focusedField == .bank && !filteredBankNames.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(filteredBankNames, id: \.self) { name in
                                        Button(name) {
                                            bankName = name
                                            filteredBankNames = [] // Clear suggestions
                                            focusedField = nil // Dismiss keyboard
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.gray)
                                    }
                                }
                                .padding(.leading, 40)
                            }
                            .frame(height: 40)
                        }
                    }

                    Label {
                        TextField("Amount", text: $amountString)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .amount)
                    } icon: {
                        Image(systemName: "dollarsign.circle") // Icon for amount
                    }
                }

                Section("Frequency & Dates") {
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(Frequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented) // Use segmented style for two options

                    // Label adjusts based on frequency
                    DatePicker(selectedFrequency == .oneTime ? "Date" : "Start Date",
                               selection: $transactionDate,
                               displayedComponents: .date)

                    // Show recurring options only if selected
                    if selectedFrequency == .recurring {
                        Toggle("Set End Date", isOn: $hasEndDate.animation())

                        if hasEndDate {
                            DatePicker("End Date",
                                       selection: Binding<Date>( // Binding to handle optional Date
                                        get: { self.recurringEndDate ?? Date() },
                                        set: { self.recurringEndDate = $0 }
                                       ),
                                       in: transactionDate..., // End date must be after start date
                                       displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle(transactionToEdit == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .disabled(!isFormDataValid())
                }
            }
        }
    }

    private func filterMerchantSuggestions(newValue: String) {
        if newValue.isEmpty {
            filteredMerchantNames = []
        } else {
            filteredMerchantNames = allMerchantNames.filter { $0.localizedCaseInsensitiveContains(newValue) }
        }
    }

    private func filterBankSuggestions(newValue: String) {
        if newValue.isEmpty {
            filteredBankNames = []
        } else {
            filteredBankNames = allBankNames.filter { $0.localizedCaseInsensitiveContains(newValue) }
        }
    }

    // Validation function
    private func isFormDataValid() -> Bool {
        guard !merchantName.isEmpty, !bankName.isEmpty, Double(amountString) != nil else {
            return false
        }
        // If recurring with end date, ensure end date is not before start date
        if selectedFrequency == .recurring, hasEndDate, let endDate = recurringEndDate {
            return endDate >= Calendar.current.startOfDay(for: transactionDate)
        }
        return true
    }

    private func saveTransaction() {
        guard let amount = Double(amountString), isFormDataValid() else {
            print("Invalid amount or form data")
            return
        }
        // Use the state variables to create form data
        let finalEndDate = (selectedFrequency == .recurring && hasEndDate) ? recurringEndDate : nil
        let formData = TransactionFormData(merchant: merchantName,
                                       bank: bankName,
                                       amount: amount,
                                       date: transactionDate,
                                       frequency: selectedFrequency,
                                       recurringEndDate: finalEndDate)
        onSave(formData)
        dismiss()
    }
}

// Preview Provider
#Preview("Add") {
    // Provide sample suggestions for preview
    AddTransactionView(allMerchantNames: ["Walmart", "Target", "Whole Foods"], allBankNames: ["Chase", "Citi", "Wells Fargo"], onSave: { _ in })
}

#Preview("Edit - One Time") {
    let previewTransaction = Transaction(merchant: "Existing Store", bank: "Existing Bank", amount: 123.45, date: Date(), frequency: .oneTime)
    return AddTransactionView(transactionToEdit: previewTransaction, allMerchantNames: ["Walmart", "Target", "Existing Store"], allBankNames: ["Chase", "Citi", "Existing Bank"], onSave: { _ in })
}

#Preview("Edit - Recurring") {
    let previewTransaction = Transaction(merchant: "Subscription", bank: "Visa", amount: 10.00, date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!, frequency: .recurring, recurringEndDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())!)
    return AddTransactionView(transactionToEdit: previewTransaction, allMerchantNames: ["Netflix", "Spotify"], allBankNames: ["Visa", "Amex"], onSave: { _ in })
} 