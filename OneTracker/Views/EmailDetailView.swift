import SwiftUI

struct EmailDetailView: View {
    let email: EmailDisplayData
    @Environment(\.dismiss) var dismiss // To add a back button if needed
    @State private var composeMode: ComposeMode? = nil // State to trigger sheet
    @EnvironmentObject var viewModel: UserViewModel // Add ViewModel access

    // State for fetched body content
    @State private var fullBody: String?
    @State private var isLoadingBody: Bool = false
    @State private var bodyErrorMessage: String?
    @State private var webViewHeight: CGFloat = .zero // State for dynamic height

    var body: some View {
        ZStack(alignment: .bottom) { // Align ZStack content to the bottom
            neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 5) {
                        Text(email.subject)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "0D2750").opacity(0.9))
                            .padding(.bottom, 5) // Add some space below subject
                        
                        HStack {
                            Text("From:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            // Use senderEmail here, fallback to sender name if nil
                            Text(email.senderEmail ?? email.sender) 
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                            
                            Spacer() // Push date to the right
                            
                            // Show Date only if it's not today
                            if !Calendar.current.isDateInToday(email.date) {
                                Text(email.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Add the "To:" field here
                        HStack { // Remove alignment: .top
                            Text("To:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(email.recipient ?? "Unknown Recipient") 
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                            Spacer() // Add Spacer here to push time to the right
                            
                            // Always show Time here
                            Text(email.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(neumorphicBackgroundStyle())
                    
                    // Body Section
                    VStack(alignment: .leading) {
                        if isLoadingBody {
                            ProgressView()
                                .padding()
                        } else if let errorMsg = bodyErrorMessage {
                            Text("Error loading content: \(errorMsg)")
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            // Display the fetched full email body using the web view
                            HTMLWebView(htmlString: fullBody ?? "<p>Loading body...</p>",
                                        dynamicHeight: $webViewHeight) // Pass height binding
                                .frame(height: webViewHeight) // Use dynamic height
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading) // Ensure body takes full width
                    .background(neumorphicBackgroundStyle())

                    // --- Thread History Section ---
                    if let history = email.previousMessages, !history.isEmpty {
                        ForEach(history) { previousEmail in
                            // Simple divider
                            Divider().padding(.vertical, 10)
                            
                            // Use the new ThreadMessageView which handles its own body fetching
                            ThreadMessageView(email: previousEmail)
                        }
                    }
                    // --- End Thread History Section ---
                    
                    // Add bottom padding to ScrollView content to prevent overlap
                    Spacer().frame(height: 100) // Height should be enough for the button bar
                }
                .padding() // Padding around the main VStack
            }

            // --- Floating Button Bar --- 
            HStack(spacing: 20) {
                // Reply Button (Neumorphic Style)
                Button {
                    // Pass the fetched fullBody to the compose mode
                    composeMode = .reply(original: email, originalBody: fullBody) 
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.headline)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Use neumorphic text color
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                }
                .background(neumorphicBackgroundColor) // Use neumorphic background
                .cornerRadius(10)
                .neumorphicDropShadow()

                // Forward Button (Neumorphic Style)
                Button {
                    // Pass the fetched fullBody to the compose mode
                    composeMode = .forward(original: email, originalBody: fullBody) 
                } label: {
                    Label("Forward", systemImage: "arrowshape.turn.up.right.fill")
                        .font(.headline)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Use neumorphic text color
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                }
                .background(neumorphicBackgroundColor) // Use neumorphic background
                .cornerRadius(10)
                .neumorphicDropShadow()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            // Keep the subtle background for the bar itself
            .background(neumorphicBackgroundColor.opacity(0.8))
             // .background(.ultraThinMaterial) // Alternative background effect
            // --- End Floating Button Bar ---
        }
        .navigationTitle("") // Use empty title, let the content define header
        .navigationBarTitleDisplayMode(.inline) // Keep title area small
        .sheet(item: $composeMode) { mode in // Present sheet based on composeMode
            ComposeEmailView(mode: mode)
                // Add neumorphic background to the sheet content if desired
                 .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all))
        }
        // Add toolbar items if needed (e.g., Reply, Delete)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button {
//                    // Action
//                } label: {
//                    Image(systemName: "arrowshape.turn.up.right.fill")
//                }
//            }
//        }
        // Add task to fetch body on appear
        .task {
            await fetchBody()
        }
    }
    
    // Function to fetch the email body
    private func fetchBody() async {
        guard fullBody == nil else { return } // Fetch only once

        isLoadingBody = true
        bodyErrorMessage = nil
        
        // Use the actual Gmail message ID and call the correct ViewModel function
        let (fetchedReply, fetchedQuote) = await viewModel.fetchFullEmailBodyParts(for: email.gmailMessageId) 
        
        isLoadingBody = false
        // Combine reply and quote for the main detail view display
        if let reply = fetchedReply {
            fullBody = reply + (fetchedQuote ?? "") // Append quote if it exists
        } else if let quote = fetchedQuote {
            fullBody = quote // If no reply, just show the quote
        } else {
            // Handle error case where both are nil
            bodyErrorMessage = viewModel.errorMessage ?? "Could not load email content."
            fullBody = nil
        }
        
        // Optional: Print combined body for debugging
        if let body = fullBody {
            print("--- BEGIN Combined Fetched Email Body ---")
            print(body)
            print("--- END Combined Fetched Email Body ---")
        } else if let errorMsg = bodyErrorMessage {
            print("Error fetching body: \(errorMsg)")
        }
    }

    // Reusing the background helper from ContentView
    @ViewBuilder
    private func neumorphicBackgroundStyle() -> some View {
        RoundedRectangle(cornerRadius: 15)
             .fill(neumorphicBackgroundColor)
             .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
             .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
}

// MARK: - View for Displaying a Single Message in a Thread (Handles Body Fetching)
struct ThreadMessageView: View {
    let email: EmailDisplayData
    @EnvironmentObject var viewModel: UserViewModel
    
    // State for fetched and parsed body content
    @State private var replyBody: String?
    @State private var quotedBody: String?
    @State private var isLoadingBody: Bool = false
    @State private var bodyErrorMessage: String?
    @State private var replyWebViewHeight: CGFloat = .zero // Height for reply part
    @State private var quotedWebViewHeight: CGFloat = .zero // Height for quoted part
    @State private var isQuotedTextExpanded = false // State for quote expansion

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Mini Header (similar to original history display)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("From:").font(.caption).foregroundColor(.secondary)
                    Text(email.senderEmail ?? email.sender).font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text(email.date.formatted(date: .numeric, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("To:").font(.caption).foregroundColor(.secondary)
                    Text(email.recipient ?? "").font(.caption).foregroundColor(.gray)
                }
                // Optionally show Subject if desired
                 Text(email.subject)
                     .font(.caption).fontWeight(.medium) // Make subject slightly stand out
                     .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                     .padding(.top, 2)
            }
            .padding(.bottom, 5)

            // Body Section (fetches and parses content)
            VStack(alignment: .leading) {
                if isLoadingBody {
                    ProgressView().padding().frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMsg = bodyErrorMessage {
                    Text("Error: \(errorMsg)").foregroundColor(.red).font(.caption).padding().frame(maxWidth: .infinity, alignment: .center)
                } else {
                    // --- Display Reply Part --- 
                    if let reply = replyBody, !reply.isEmpty {
                         HTMLWebView(htmlString: reply, dynamicHeight: $replyWebViewHeight)
                             .frame(height: replyWebViewHeight)
                    } else if quotedBody == nil {
                        // If no reply and no quote, show placeholder or empty view
                        Text("<i>(Empty message body)</i>") // Placeholder
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // --- Display Quoted Part (Expandable) --- 
                    if let quote = quotedBody {
                        VStack(alignment: .leading) {
                            if isQuotedTextExpanded {
                                // Expanded View: Use HTMLWebView for the quote
                                HTMLWebView(htmlString: quote, dynamicHeight: $quotedWebViewHeight)
                                    .frame(height: quotedWebViewHeight)
                                    .background(Color.clear)
                                    .padding(.vertical, 10)
                            } else {
                                // Collapsed View (Preview): Use Text
                                HStack {
                                    Text(quotePreview(quote)) // Use preview helper
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    Spacer()
                                    Image(systemName: "ellipsis") // Use ellipsis icon
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(5)
                        .background(neumorphicBackgroundStyle().opacity(0.6)) // Different background for quote
                        .onTapGesture {
                            withAnimation {
                                isQuotedTextExpanded.toggle()
                            }
                        }
                        .transition(.opacity)
                        .padding(.top, 10) // Space between reply and quote
                    }
                }
            }
            // Body fetch logic
            .task {
                // Capture viewModel explicitly for use in async context
                let capturedViewModel = viewModel 
                await fetchBodyParts(viewModel: capturedViewModel)
            }
        }
        .padding()
        .background(neumorphicBackgroundStyle().opacity(0.8))
    }
    
    // Function to fetch and parse the email body
    // Pass viewModel explicitly as it might be captured
    private func fetchBodyParts(viewModel: UserViewModel) async {
        // Avoid refetching if already attempted
        guard replyBody == nil && quotedBody == nil else { return } 

        isLoadingBody = true
        bodyErrorMessage = nil
        
        // Call the new ViewModel function that returns parts
        let (fetchedReply, fetchedQuote) = await viewModel.fetchFullEmailBodyParts(for: email.gmailMessageId) 
        
        isLoadingBody = false
        // Check for specific error message from ViewModel
        if fetchedReply == nil && fetchedQuote == nil && viewModel.errorMessage != nil {
             bodyErrorMessage = viewModel.errorMessage
        } else {
             // Assign fetched parts to state variables
             replyBody = fetchedReply
             quotedBody = fetchedQuote
        }
    }
    
    // Quote Preview Helper (Copied and adapted from ComposeEmailView)
    private func quotePreview(_ fullQuoteHtml: String) -> String {
        // Basic HTML stripping and decoding (same as ComposeEmailView's helper)
        let tagStrippingRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive)
        let range = NSRange(fullQuoteHtml.startIndex..<fullQuoteHtml.endIndex, in: fullQuoteHtml)
        let plainTextQuote = tagStrippingRegex?.stringByReplacingMatches(in: fullQuoteHtml, options: [], range: range, withTemplate: "") ?? fullQuoteHtml
        
        let decodedText = plainTextQuote
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Return first few lines or a default message
        let lines = decodedText.split(separator: "\n", maxSplits: 3, omittingEmptySubsequences: true)
        if lines.isEmpty {
            return "-- Quoted Text --"
        } else {
            // Join first few lines, add ellipsis if more content
            return lines.joined(separator: " ") + (decodedText.count > 100 ? "..." : "") // Simple length check for ellipsis
        }
    }
    
    // Neumorphic style helper (copied for self-containment)
    @ViewBuilder
    private func neumorphicBackgroundStyle() -> some View {
        RoundedRectangle(cornerRadius: 15)
             .fill(Color(hex: "F0F0F3")) // Use actual color value
             .shadow(color: Color.black.opacity(0.2), radius: 5, x: 5, y: 5)
             .shadow(color: Color.white.opacity(0.7), radius: 5, x: -5, y: -5)
    }
}

// MARK: - Preview
struct EmailDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock data first
        let originalEmail = EmailDisplayData(
            gmailMessageId: "originalMsgId",
            threadId: "previewThread1",
            messageIdHeader: "<original-preview@example.com>",
            referencesHeader: nil,
            sender: "Alice (Preview)",
            senderEmail: "alice.preview@example.com",
            recipient: "Bob (Preview)",
            subject: "Project Update",
            snippet: "Initial project update...",
            body: "Hi Bob,\n\nHere's the initial update on the project.\n\nBest,\nAlice",
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            isRead: true,
            previousMessages: nil
        )
        var reply1 = EmailDisplayData(
            gmailMessageId: "reply1MsgId",
            threadId: "previewThread1",
            messageIdHeader: "<reply1-preview@example.com>",
            referencesHeader: originalEmail.messageIdHeader,
            sender: "Bob (Preview)",
            senderEmail: "bob.preview@example.com",
            recipient: "Alice (Preview)",
            subject: "Re: Project Update",
            snippet: "Thanks for the update, Alice...",
            body: "Hi Alice,\n\nThanks for the update! A couple of questions...\n\nBest,\nBob",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            isRead: true,
            previousMessages: nil // Initialize as nil first
        )
        var reply2 = EmailDisplayData(
            gmailMessageId: "reply2MsgId",
            threadId: "previewThread1",
            messageIdHeader: "<reply2-preview@example.com>",
            referencesHeader: "\(originalEmail.messageIdHeader ?? "") \(reply1.messageIdHeader ?? "")",
            sender: "Alice (Preview)",
            senderEmail: "alice.preview@example.com",
            recipient: "Bob (Preview)",
            subject: "Re: Project Update",
            snippet: "Here's some clarification...",
            body: "Hi Bob,\n\nHere are answers to your questions...\n\nBest,\nAlice",
            date: Date(),
            isRead: false,
            previousMessages: nil // Initialize as nil first
        )
        
        // --- Perform setup outside the ViewBuilder return --- 
        reply1.previousMessages = [originalEmail]
        reply2.previousMessages = [reply1]
        // --- End Setup ---

        // Now return the actual view
        return NavigationView {
            EmailDetailView(email: reply2)
        }
    }
} 