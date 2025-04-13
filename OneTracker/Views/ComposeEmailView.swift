import SwiftUI

// Enum to define the purpose of the compose view
enum ComposeMode: Identifiable {
    case new
    case reply(original: MockEmail)
    case forward(original: MockEmail)
    
    // Make identifiable for use with .sheet(item:)
    var id: String {
        switch self {
        case .new: return "new"
        case .reply(let email): return "reply-\(email.id)"
        case .forward(let email): return "forward-\(email.id)"
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
    
    // Mock sender emails (replace with actual account logic later)
    private let senderEmails = ["user@example.com", "work@example.com", "alias@example.com"]
    
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
                            // To Field
                            ComposeFieldView(label: "To:", text: $recipient, focusedField: $focusedField, fieldIdentifier: .recipient)
                            
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
                                        ForEach(senderEmails, id: \.self) { email in
                                            Text(email).tag(email)
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
                                ComposeFieldView(label: "Cc:", text: $ccRecipient, placeholder: "Cc Recipient(s)", focusedField: $focusedField, fieldIdentifier: .cc)
                                Divider()
                                ComposeFieldView(label: "Bcc:", text: $bccRecipient, placeholder: "Bcc Recipient(s)", focusedField: $focusedField, fieldIdentifier: .bcc)
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
                                    // Expanded View
                                    Text(quote)
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    // Collapsed View (Preview)
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
                        // TODO: Implement actual sending logic
                        print("Send tapped!")
                        print("From: \(selectedSender)") // Use selected sender
                        print("To: \(recipient)")
                        if !ccRecipient.isEmpty { print("Cc: \(ccRecipient)") }
                        if !bccRecipient.isEmpty { print("Bcc: \(bccRecipient)") }
                        dismiss()
                    }
                    .font(.headline)
                }
            }
            .onAppear {
                // Set initial sender and call content setup
                selectedSender = userViewModel.userEmail ?? senderEmails.first ?? "error@example.com"
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
        case .reply(let originalEmail):
            recipient = originalEmail.sender 
            subject = "Re: \(originalEmail.subject)"
            // Generate quote WITHOUT '>' prefix
            quotedText = "---\nOn \(originalEmail.date.formatted(date: .abbreviated, time: .shortened)), \(originalEmail.sender) wrote:\n\n\(originalEmail.body)" // Removed replacingOccurrences
            bodyText = "\n\n"
        case .forward(let originalEmail):
            subject = "Fwd: \(originalEmail.subject)" 
            // Generate forward text WITHOUT '>' prefix
            quotedText = "---\nForwarded message:\nFrom: \(originalEmail.sender)\nDate: \(originalEmail.date.formatted(date: .abbreviated, time: .shortened))\nSubject: \(originalEmail.subject)\n\n\(originalEmail.body)"
            bodyText = ""
        }
    }

    // Helper to get quote preview (show actual body lines)
    private func quotePreview(_ fullQuote: String) -> String {
        let lines = fullQuote.split(separator: "\n", omittingEmptySubsequences: false)
        var bodyPreviewLines: [String] = []
        var foundBody = false
        let maxPreviewLines = 3 // Number of body lines to show in preview

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            // Skip header lines until we find an empty line or the actual body starts
            if foundBody {
                if bodyPreviewLines.count < maxPreviewLines {
                    bodyPreviewLines.append(String(line))
                } else {
                    break
                }
            } else if trimmedLine.isEmpty && lines.firstIndex(of: line) ?? 0 > 2 { // Heuristic: body starts after first empty line (past initial headers)
                 foundBody = true
            } else if !(trimmedLine.starts(with: "---") || trimmedLine.starts(with: "On ") || trimmedLine.starts(with: "From:") || trimmedLine.starts(with: "Date:") || trimmedLine.starts(with: "Subject:") || trimmedLine.starts(with: "Forwarded message:")) {
                 // If it's not a header line and we haven't found an empty separator line, assume it's body
                 foundBody = true
                 if bodyPreviewLines.count < maxPreviewLines {
                     bodyPreviewLines.append(String(line))
                 } else {
                     break
                 }
            }
        }
        
        if bodyPreviewLines.isEmpty {
            // Fallback if no body found (e.g., only headers in quote)
             return "-- Quoted Text --"
        }

        return bodyPreviewLines.joined(separator: "\n")
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

// Reusable View for To/Cc/Bcc fields
struct ComposeFieldView: View {
    let label: String
    @Binding var text: String
    var placeholder: String? = nil
    
    // Add focus state binding and identifier
    var focusedField: FocusState<ComposeEmailView.Field?>.Binding
    let fieldIdentifier: ComposeEmailView.Field

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            TextField(placeholder ?? "Recipient(s)", text: $text)
                .font(.subheadline)
                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                .focused(focusedField, equals: fieldIdentifier) // Apply focus here
        }
    }
}

// MARK: - Preview
struct ComposeEmailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = UserViewModel()
        mockViewModel.userEmail = "preview.user@example.com"
        
        // Explicitly return the view
        return ComposeEmailView(mode: .new)
            .environmentObject(mockViewModel)
    }
} 