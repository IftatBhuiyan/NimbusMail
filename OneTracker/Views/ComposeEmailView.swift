import SwiftUI

// MARK: - AutoCompleteField View
struct AutoCompleteField: View {
    let label: String
    @Binding var text: String
    let suggestions: [String]
    var placeholder: String? = nil
    
    // Focus state binding and identifier
    var focusedField: FocusState<ComposeEmailView.Field?>.Binding
    let fieldIdentifier: ComposeEmailView.Field

    // State for filtered suggestions and visibility
    @State private var filteredSuggestions: [String] = []
    @State private var showSuggestions: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { // Use VStack to stack TextField and suggestions
            // Original Field Layout (slightly modified)
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading) // Maintain label width
                
                TextField(placeholder ?? "Recipient(s)", text: $text)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused(focusedField, equals: fieldIdentifier)
                    .onChange(of: text) { oldValue, newValue in
                         updateSuggestions(for: newValue)
                     }
                    .onChange(of: focusedField.wrappedValue) { oldFocus, newFocus in
                        // Show suggestions only when this specific field is focused
                        if newFocus == fieldIdentifier {
                            updateSuggestions(for: text) // Update suggestions when gaining focus
                        } else {
                            // Delay hiding slightly to allow tap on suggestion
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.showSuggestions = false
                            }
                        }
                    }
            }
            .padding(.vertical, 5) // Add some padding around the text field Hstack

            // Suggestions View (built with ScrollView + ForEach)
            if showSuggestions && !filteredSuggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)) // Consistent padding
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(neumorphicBackgroundColor) // Apply background to row
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    self.text = suggestion
                                    self.showSuggestions = false
                                    focusedField.wrappedValue = nil
                                }
                            Divider().padding(.leading, 12) // Add divider, indent slightly
                        }
                    }
                }
                .frame(maxHeight: 150) // Limit height
                .background(neumorphicBackgroundColor) // Background for the whole scroll area
                .cornerRadius(10) // Round corners
                 .modifier(NeumorphicInnerShadow()) // Apply shadow to the container
                 .transition(.opacity.combined(with: .move(edge: .top)))
                 .padding(.leading, 60) // Align with TextField input area
                 .zIndex(1) // Keep on top
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSuggestions) // Animate suggestions visibility
    }

    private func updateSuggestions(for input: String) {
        guard focusedField.wrappedValue == fieldIdentifier else {
             // Not focused, clear and hide
             if showSuggestions { print("[AutoComplete Debug \(label)] Clearing suggestions (focus lost)") }
             filteredSuggestions = []
             showSuggestions = false
             return
         }
        
        print("[AutoComplete Debug \(label)] Updating suggestions for input: '\(input)'")
        print("[AutoComplete Debug \(label)] Full suggestion list: \(suggestions)") // Log the full list

        if input.isEmpty {
            print("[AutoComplete Debug \(label)] Input empty, hiding suggestions.")
            filteredSuggestions = []
            showSuggestions = false
        } else {
            // Simple filtering: suggestions containing the input text (case-insensitive)
            let lowercasedInput = input.lowercased()
            filteredSuggestions = suggestions.filter {
                $0.lowercased().contains(lowercasedInput) && $0.lowercased() != lowercasedInput
            }
            showSuggestions = !filteredSuggestions.isEmpty
            print("[AutoComplete Debug \(label)] Filtered suggestions: \(filteredSuggestions)")
            print("[AutoComplete Debug \(label)] showSuggestions: \(showSuggestions)")
        }
    }
    
    // Need access to neumorphic style helpers
    private var neumorphicBackgroundColor: Color { Color(hex: "F0F0F3") } // Ensure consistent
}

// --- End AutoCompleteField View ---

// Enum to define the purpose of the compose view
enum ComposeMode: Identifiable {
    case new
    case reply(original: EmailDisplayData, originalBody: String?)
    case forward(original: EmailDisplayData, originalBody: String?)
    
    // Make identifiable for use with .sheet(item:)
    var id: String {
        switch self {
        case .new: return "new"
        case .reply(let email, _): return "reply-\(email.id)"
        case .forward(let email, _): return "forward-\(email.id)"
        }
    }
}

struct ComposeEmailView: View {
    let mode: ComposeMode
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    
    // Add FocusState to track field focus
    @FocusState private var focusedField: Field?
    
    enum Field {
        case recipient, subject, body, cc, bcc
    }
    
    // State for email fields
    @State private var recipient: String = ""
    @State private var subject: String = ""
    @State private var bodyText: String = ""
    @State private var selectedSender: String = ""
    @State private var ccRecipient: String = ""
    @State private var bccRecipient: String = ""
    @State private var showCcBccFields = false
    @State private var quotedText: String? = nil // State for quoted text
    @State private var isQuotedTextExpanded = false // State for quote expansion
    @State private var quotedWebViewHeight: CGFloat = .zero // State for quote web view height
    
    var body: some View {
        NavigationView { 
            ZStack(alignment: .bottom) { // Keep ZStack alignment to bottom
                neumorphicBackgroundColor
                    .edgesIgnoringSafeArea(.all)
                    .contentShape(Rectangle()) // Make background tappable
                    .onTapGesture {
                        // Tapping the background dismisses keyboard AND collapses fields
                        print("Background tapped") // Debugging
                        focusedField = nil // Dismiss keyboard
                        checkAndCollapseCcBccFields()
                    }
                
                // ScrollView containing main input fields
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // To/From/Cc/Bcc Field Card
                        VStack(alignment: .leading, spacing: 8) {
                            // Replace To Field
                            AutoCompleteField(label: "To:", 
                                              text: $recipient, 
                                              suggestions: userViewModel.suggestedContacts, // Pass suggestions
                                              focusedField: $focusedField, 
                                              fieldIdentifier: .recipient)
                            
                            Divider()
                            
                            // From Field (Picker)
                            HStack(alignment: .center) { // Center align Menu content vertically
                                Text("From:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                
                                // Use a Menu for sender selection
                                Menu {
                                    Picker("Select Sender", selection: $selectedSender) {
                                        // Iterate over viewModel accounts
                                        ForEach(userViewModel.addedAccounts) { account in
                                            Text(account.emailAddress).tag(account.emailAddress)
                                        }
                                    }
                                } label: {
                                    Text(selectedSender)
                                        .font(.subheadline)
                                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.down") // Indicate it's a picker
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .id(selectedSender) // Ensure menu updates when selection changes
                            }
                            .padding(.bottom, 4) // Add slight padding below picker

                            // --- Conditional Cc/Bcc Section ---
                            if showCcBccFields {
                                Divider()
                                // Replace Cc Field
                                AutoCompleteField(label: "Cc:", 
                                                  text: $ccRecipient, 
                                                  suggestions: userViewModel.suggestedContacts, 
                                                  placeholder: "Cc Recipient(s)", 
                                                  focusedField: $focusedField, 
                                                  fieldIdentifier: .cc)
                                Divider()
                                // Replace Bcc Field
                                AutoCompleteField(label: "Bcc:", 
                                                  text: $bccRecipient, 
                                                  suggestions: userViewModel.suggestedContacts, 
                                                  placeholder: "Bcc Recipient(s)", 
                                                  focusedField: $focusedField, 
                                                  fieldIdentifier: .bcc)
                            } else {
                                Divider() // Divider before the combined field
                                HStack {
                                    Text("Cc/Bcc") // Combined placeholder text
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    Spacer() // Push to the right
                                }
                                .contentShape(Rectangle()) // Make the whole HStack tappable
                                .onTapGesture {
                                    withAnimation {
                                        showCcBccFields = true
                                    }
                                }
                                .padding(.vertical, 5) // Add some vertical padding for tap area
                            }
                            // --- End Conditional Cc/Bcc Section ---
                            
                        }
                        .padding()
                        .background(neumorphicBackgroundStyle())

                        // Subject Field Card
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Subject:").font(.caption).foregroundColor(.secondary).padding(.leading, 5)
                            TextField("Subject", text: $subject)
                                .focused($focusedField, equals: .subject)
                                .font(.subheadline) // Match font size
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                        }
                        .padding(8)
                        .background(neumorphicBackgroundStyle())

                        // Body TextEditor Section
                        TextEditor(text: $bodyText)
                            .focused($focusedField, equals: .body)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .font(.body)
                            .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                            .lineSpacing(5)
                            .frame(minHeight: 300)
                            .padding(10)
                            .modifier(NeumorphicInnerShadow())

                        Spacer() // Pushes quote card down

                        // --- Quoted Text Card ---
                        if let quote = quotedText {
                            VStack(alignment: .leading) {
                                if isQuotedTextExpanded {
                                    // Expanded View: Use HTMLWebView
                                    HTMLWebView(htmlString: quote, dynamicHeight: $quotedWebViewHeight)
                                        .frame(height: quotedWebViewHeight) // Use dynamic height
                                        // Optionally add some styling or background to the webview container
                                        .background(Color.clear) // Match background
                                        .padding(10)
                                } else {
                                    // Collapsed View (Preview): Use Text
                                    HStack {
                                        Text(quotePreview(quote))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(10)
                            .background(neumorphicBackgroundStyle())
                            .onTapGesture {
                                withAnimation {
                                    isQuotedTextExpanded.toggle()
                                }
                            }
                            .transition(.opacity)
                            .padding(.top, -20) // Increased negative top padding
                        }
                        // --- End Quoted Text Card ---
                    }
                    .padding() 
                    .padding(.bottom, 20) 
                    .frame(maxHeight: .infinity, alignment: .top) // Make VStack fill available height
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { oldFocus, newFocus in
                     print("Focus changed from \(String(describing: oldFocus)) to \(String(describing: newFocus))")
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        // Start async task to send email
                        Task {
                            do {
                                // Gather data (use nil for empty cc/bcc)
                                let cc = ccRecipient.isEmpty ? nil : ccRecipient
                                let bcc = bccRecipient.isEmpty ? nil : bccRecipient
                                
                                // Extract original email if in reply/forward mode
                                var originalEmailForReply: EmailDisplayData? = nil
                                if case .reply(let original, _) = mode {
                                    originalEmailForReply = original
                                }
                                // TODO: Decide if forward should also pass originalEmail for threading reference (might be useful)
                                
                                try await userViewModel.sendEmail(
                                    to: recipient, 
                                    cc: cc, 
                                    bcc: bcc, 
                                    subject: subject, 
                                    bodyText: bodyText, 
                                    quotedText: quotedText, // Pass the original HTML quote
                                    fromAddress: selectedSender,
                                    originalEmail: originalEmailForReply // Pass original email only for replies
                                )
                                // Dismiss on success
                                print("Send successful, dismissing view.")
                                dismiss()
                            } catch {
                                // Handle error (e.g., show alert)
                                print("Error sending email: \(error.localizedDescription)")
                                // TODO: Show an alert to the user
                                // errorMessage = error.localizedDescription
                                // showingSendErrorAlert = true
                            }
                        }
                    }
                    .font(.headline)
                     // Optionally disable button while sending
                     .disabled(userViewModel.isLoading) 
                }
            }
            .onAppear {
                // Set initial sender and call content setup
                // Use the first added account if available
                selectedSender = userViewModel.addedAccounts.first?.emailAddress ?? "No Account"
                setupInitialContent()
            }
        }
        .accentColor(.blue)
    }
    
    // --- Helper Properties & Methods ---

    private var navigationTitle: String {
        switch mode {
        case .new: return "New Message"
        case .reply: return "Reply"
        case .forward: return "Forward"
        }
    }
    
    // Function to check if Cc/Bcc fields are empty and collapse them
    private func checkAndCollapseCcBccFields() {
        print("Checking collapse conditions...")
        // No need to check focus here, as this is only called on background tap
        if showCcBccFields && ccRecipient.isEmpty && bccRecipient.isEmpty {
            print("Collapsing CC/BCC fields.")
            withAnimation {
                showCcBccFields = false
            }
        }
    }
    
    // Determine if recipient field should be locked (e.g., for reply)
    // For simplicity, let's keep it editable for now.
    private var isRecipientLocked: Bool {
        switch mode {
        case .new: return false
        case .reply: return false // Allow editing/adding recipients
        case .forward: return false
        }
    }

    // Setup fields based on the compose mode
    private func setupInitialContent() {
        ccRecipient = ""
        bccRecipient = ""
        quotedText = nil
        isQuotedTextExpanded = false
        
        switch mode {
        case .new:
            bodyText = ""
            break
        case .reply(let originalEmail, let originalBody):
            recipient = originalEmail.senderEmail ?? originalEmail.sender 
            subject = "Re: \(originalEmail.subject)"
            let bodyToQuote = originalBody ?? originalEmail.body
            quotedText = "---\nOn \(originalEmail.date.formatted(date: .abbreviated, time: .shortened)), \(originalEmail.sender) wrote:\n\n\(bodyToQuote)"
            bodyText = "\n\n"
        case .forward(let originalEmail, let originalBody):
            subject = "Fwd: \(originalEmail.subject)" 
            let bodyToQuote = originalBody ?? originalEmail.body
            quotedText = "---\nForwarded message:\nFrom: \(originalEmail.sender)\nDate: \(originalEmail.date.formatted(date: .abbreviated, time: .shortened))\nSubject: \(originalEmail.subject)\n\n\(bodyToQuote)"
            bodyText = ""
        }
    }

    // Helper to get quote preview (show actual body lines after stripping HTML)
    private func quotePreview(_ fullQuoteHtml: String) -> String {
        // 1. Attempt to strip HTML tags using a basic regex
        let tagStrippingRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive)
        let range = NSRange(fullQuoteHtml.startIndex..<fullQuoteHtml.endIndex, in: fullQuoteHtml)
        let plainTextQuote = tagStrippingRegex?.stringByReplacingMatches(in: fullQuoteHtml, options: [], range: range, withTemplate: "") ?? fullQuoteHtml
        
        // 2. Decode HTML entities (simple cases)
        let decodedText = plainTextQuote
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            // Add more entities if needed

        // 3. Generate preview from the plain text
        let lines = decodedText.split(separator: "\n", omittingEmptySubsequences: false)
        var bodyPreviewLines: [String] = []
        var foundBody = false
        let maxPreviewLines = 2 // Keep preview short
        let headerKeywords = ["---", "on ", "from:", "date:", "subject:", "forwarded message:"]

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip quote headers
            if headerKeywords.contains(where: { trimmedLine.lowercased().starts(with: $0) }) {
                continue
            }
            
            // Once headers are passed, start taking non-empty lines for preview
            if !trimmedLine.isEmpty {
                 foundBody = true
                 if bodyPreviewLines.count < maxPreviewLines {
                     bodyPreviewLines.append(trimmedLine)
                 } else {
                     break
                 }
            }
        }
        
        if !foundBody || bodyPreviewLines.isEmpty {
             return "-- Quoted Text --"
        }

        return bodyPreviewLines.joined(separator: " ") // Join with space for preview
    }

    // --- Add Neumorphic Background Helper (if not global) ---
    // This should ideally live in NeumorphismStyles.swift
    @ViewBuilder
    private func neumorphicBackgroundStyle() -> some View {
        RoundedRectangle(cornerRadius: 15)
             .fill(neumorphicBackgroundColor)
             .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
             .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
}

// MARK: - Preview
struct ComposeEmailView_Previews: PreviewProvider {
    static var previews: some View {
        // Use the non-mock ViewModel initializer for previews
        let mockViewModel = UserViewModel() 
        mockViewModel.userEmail = "preview.user@example.com"
        
        // Explicitly return the view
        return ComposeEmailView(mode: .new)
            .environmentObject(mockViewModel)
    }
} 