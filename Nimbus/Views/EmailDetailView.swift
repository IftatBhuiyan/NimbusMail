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
    @State private var bodyHTML: String? = nil
    @State private var quoteHTML: String? = nil // Store quote separately if needed later

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
                    
                    // --- Display Labels/Tags --- 
                    if let labelIds = email.labelIds, !labelIds.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(labelIds, id: \.self) { labelId in
                                    // You might want to map IDs to names if you fetched labels
                                    // For now, just display the ID (cleaned up)
                                    Text(formatLabelId(labelId))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(5)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 5) // Add padding below tags
                    }
                    // --- End Display Labels --- 
                    
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
        // Add task to fetch body and mark as read on appear
        .task {
            // Call both async functions concurrently if desired,
            // or sequentially if marking read should happen first/after body loads.
            // For now, let's run them concurrently.
            async let fetchBodyTask: Void = fetchBody()
            async let markReadTask: Void = viewModel.markAsRead(email: email)
            
            _ = await [fetchBodyTask, markReadTask] // Wait for both to complete
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

    // Helper to format label IDs for display
    private func formatLabelId(_ labelId: String) -> String {
        if labelId.starts(with: "CATEGORY_") {
            return labelId.replacingOccurrences(of: "CATEGORY_", with: "").capitalized
        }
        return labelId.capitalized.replacingOccurrences(of: "_", with: " ")
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
    
    // New state for thread message collapse/expand
    @State private var isThreadExpanded = false // Collapsed by default
    
    // Task for cancellation
    @State private var fetchBodyTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Always visible header section (tappable to expand/collapse)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isThreadExpanded.toggle()
                    
                    // Only load message body when expanded and not already loaded
                    if isThreadExpanded && replyBody == nil && quotedBody == nil && !isLoadingBody {
                        loadMessageBody()
                    }
                }
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Expand/collapse indicator
                        Image(systemName: isThreadExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        Text("From:").font(.caption).foregroundColor(.secondary)
                        Text(email.senderEmail ?? email.sender).font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text(email.date.formatted(date: .numeric, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    if !isThreadExpanded {
                        // Preview of subject and snippet when collapsed
                        VStack(alignment: .leading, spacing: 2) {
                            Text(email.subject)
                                .font(.caption).fontWeight(.medium)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                                .lineLimit(1)
                            
                            // Add snippet preview for better context
                            Text(email.snippet)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .padding(.leading, 18) // Align with content after chevron
                    }
                }
            }
            .buttonStyle(PlainButtonStyle()) // Remove default button styling
            
            // Expandable content section
            if isThreadExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Additional header info (only shown when expanded)
                    HStack {
                        Text("To:").font(.caption).foregroundColor(.secondary)
                        Text(email.recipient ?? "").font(.caption).foregroundColor(.gray)
                    }
                    .padding(.leading, 18) // Align with content after chevron
                    
                    Text(email.subject)
                        .font(.caption).fontWeight(.medium)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                        .padding(.leading, 18) // Align with content after chevron
                        .padding(.top, 2)
                    
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
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(neumorphicBackgroundStyle().opacity(0.8))
        .contentShape(Rectangle()) // Make the entire area tappable
        .onDisappear {
            // Cancel any ongoing fetch when view disappears
            fetchBodyTask?.cancel()
        }
    }
    
    // Function to load message body in a cancellable task
    private func loadMessageBody() {
        // Cancel any existing task
        fetchBodyTask?.cancel()
        
        // Create a new task
        fetchBodyTask = Task {
            await fetchBodyParts(viewModel: viewModel)
        }
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

// MARK: - View for Previous Messages in Thread
struct PreviousMessageView: View {
    let email: EmailDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(email.sender)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                Spacer()
                Text(email.date.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(email.snippet) // Display the snippet for content
                .font(.footnote)
                .foregroundColor(.gray)
                .lineLimit(3) // Limit snippet lines if needed
        }
        .padding()
        .background(neumorphicBackgroundStyle()) // Apply consistent styling
    }
    
    // Re-use the neumorphic style helper
    private func neumorphicBackgroundStyle() -> some View {
        RoundedRectangle(cornerRadius: 10) // Slightly smaller radius?
            .fill(neumorphicBackgroundColor)
            .shadow(color: darkDropShadowColor.opacity(0.8), radius: (darkDropShadowBlur / 2) * 0.8, x: (darkDropShadowX / 2) * 0.8, y: (darkDropShadowY / 2) * 0.8) // Slightly subtle shadow
            .shadow(color: lightDropShadowColor.opacity(0.8), radius: (lightDropShadowBlur / 2) * 0.8, x: (lightDropShadowX / 2) * 0.8, y: (lightDropShadowY / 2) * 0.8)
    }
}

// struct EmailDetailView_Previews: PreviewProvider { ... } // Remove this entire block 