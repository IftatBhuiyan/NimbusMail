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
    @State private var merchantName: String
    @State private var bankName: String
    @State private var amountString: String
    @State private var transactionDate: Date
    @State private var selectedFrequency: Frequency
    @State private var recurringEndDate: Date?
    @State private var hasEndDate: Bool

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

    // Computed property for view title
    private var viewTitle: String {
        transactionToEdit == nil ? "Add Transaction" : "Edit Transaction"
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

    var body: some View {
        // Replace NavigationView with VStack for manual control
        VStack(spacing: 0) {
            // Custom Header (Replaces Navigation Bar)
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(NeumorphicButtonStyle()) // Apply style
                
                Spacer()
                
                Text(viewTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                
                Spacer()
                
                Button("Save") {
                    saveTransaction()
                }
                .buttonStyle(NeumorphicButtonStyle())
                .disabled(!isFormDataValid())
                
            }
            .padding()
            .background(neumorphicBackgroundColor) // Header background
            
            // Use ScrollView instead of Form for flexible styling
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { // Main content stack
                    
                    // --- Transaction Details Card --- 
                    SectionHeader(title: "Transaction Details")
                    
                    VStack(alignment: .leading, spacing: 15) {
                        // Merchant Input
                        VStack(alignment: .leading) {
                            Label {
                                TextField("Merchant Name", text: $merchantName)
                                    .focused($focusedField, equals: .merchant)
                                    .onChange(of: merchantName) { filterMerchantSuggestions(newValue: $1) }
                                    .textFieldStyle(NeumorphicTextFieldStyle())
                            } icon: {
                                Image(systemName: "storefront")
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                            }

                            // Merchant Suggestions
                            if focusedField == .merchant && !filteredMerchantNames.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(filteredMerchantNames, id: \.self) { name in
                                            Button(name) {
                                                merchantName = name
                                                filteredMerchantNames = []
                                                focusedField = nil
                                            }
                                            .buttonStyle(NeumorphicButtonStyle()) // Style suggestions
                                            .font(.caption)
                                        }
                                    }
                                }
                                .frame(height: 40)
                                .padding(.leading, 30) // Indent suggestions
                            }
                        }
                        
                        // Bank Input
                        VStack(alignment: .leading) {
                            Label {
                                TextField("Bank Name", text: $bankName)
                                    .focused($focusedField, equals: .bank)
                                    .onChange(of: bankName) { filterBankSuggestions(newValue: $1) }
                                    .textFieldStyle(NeumorphicTextFieldStyle())
                            } icon: {
                                Image(systemName: "building.columns")
                                     .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                            }

                            // Bank Suggestions
                            if focusedField == .bank && !filteredBankNames.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                     HStack {
                                        ForEach(filteredBankNames, id: \.self) { name in
                                            Button(name) {
                                                bankName = name
                                                filteredBankNames = []
                                                focusedField = nil
                                            }
                                            .buttonStyle(NeumorphicButtonStyle())
                                            .font(.caption)
                                        }
                                    }
                                }
                                .frame(height: 40)
                                .padding(.leading, 30)
                            }
                        }

                        // Amount Input
                        Label {
                            TextField("Amount", text: $amountString)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .amount)
                                .textFieldStyle(NeumorphicTextFieldStyle())
                        } icon: {
                            Image(systemName: "dollarsign.circle")
                                 .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                        }
                    }
                    .padding()
                    .background(neumorphicCardBackground()) // Card background

                    // --- Frequency & Dates Card --- 
                    SectionHeader(title: "Frequency & Dates")
                    
                    VStack(alignment: .leading, spacing: 15) {
                         // Frequency Picker
                         Picker("Frequency", selection: $selectedFrequency) {
                            ForEach(Frequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                         .background(neumorphicBackgroundColor.opacity(0.6)) // Subtle background
                         .cornerRadius(8)
                        
                        // Date Picker (Start Date)
                        DatePicker(selectedFrequency == .oneTime ? "Date" : "Start Date",
                                   selection: $transactionDate,
                                   displayedComponents: .date)
                         .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                         .accentColor(Color(hex: "0D2750").opacity(0.8))

                        // Recurring Options
                        if selectedFrequency == .recurring {
                            Toggle("Set End Date", isOn: $hasEndDate.animation())
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                .tint(Color.blue) // Keep a standard tint for toggle

                            if hasEndDate {
                                DatePicker("End Date",
                                           selection: Binding<Date>( // Binding for optional Date
                                            get: { self.recurringEndDate ?? Date() },
                                            set: { self.recurringEndDate = $0 }
                                           ),
                                           in: transactionDate...,
                                           displayedComponents: .date)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                    .accentColor(Color(hex: "0D2750").opacity(0.8))
                            }
                        }
                    }
                    .padding()
                    .background(neumorphicCardBackground()) // Card background
                    
                } // End Main VStack for content
                .padding() // Padding around the content cards
            } // End ScrollView
            .background(neumorphicBackgroundColor) // Ensure scroll view background matches
            .ignoresSafeArea(.keyboard, edges: .bottom) // Prevent keyboard overlap
        } // End Outer VStack
    }

    // --- Helper Functions --- 

    private func filterMerchantSuggestions(newValue: String) {
        if newValue.isEmpty {
            filteredMerchantNames = []
        } else {
            // Simple prefix matching for better performance potentially
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
            // Consider showing an alert to the user
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

    // Helper for card background (assumes definition exists in NeumorphismStyles.swift or similar)
    @ViewBuilder
    private func neumorphicCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(neumorphicBackgroundColor)
            .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
            .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
}

// Preview Provider
#Preview("Add") {
    // Provide sample suggestions for preview
    AddTransactionView(allMerchantNames: ["Walmart", "Target", "Whole Foods"], allBankNames: ["Chase", "Citi", "Wells Fargo"], onSave: { _ in })
        // Apply background for preview context
        .background(neumorphicBackgroundColor)
}

#Preview("Edit - One Time") {
    let previewTransaction = Transaction(merchant: "Existing Store", bank: "Existing Bank", amount: 123.45, date: Date(), frequency: .oneTime)
    return AddTransactionView(transactionToEdit: previewTransaction, allMerchantNames: ["Walmart", "Target", "Existing Store"], allBankNames: ["Chase", "Citi", "Existing Bank"], onSave: { _ in })
        .background(neumorphicBackgroundColor)
}

#Preview("Edit - Recurring") {
    let previewTransaction = Transaction(merchant: "Subscription", bank: "Visa", amount: 10.00, date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!, frequency: .recurring, recurringEndDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())!)
    return AddTransactionView(transactionToEdit: previewTransaction, allMerchantNames: ["Netflix", "Spotify"], allBankNames: ["Visa", "Amex"], onSave: { _ in })
        .background(neumorphicBackgroundColor)
} 