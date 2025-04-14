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
                            
                            // Display Previous Email (could be a reusable view)
                            VStack(alignment: .leading, spacing: 15) {
                                // Mini Header for previous email
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("From:").font(.caption).foregroundColor(.secondary)
                                        Text(previousEmail.sender).font(.caption).foregroundColor(.gray)
                                        Spacer()
                                        // Display date/time for previous emails simply
                                        Text(previousEmail.date.formatted(date: .numeric, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    HStack {
                                        Text("To:").font(.caption).foregroundColor(.secondary)
                                        Text(previousEmail.recipient ?? "").font(.caption).foregroundColor(.gray)
                                    }
                                }
                                .padding(.bottom, 5)
                                
                                // Previous email body
                                Text(previousEmail.body)
                                    .font(.footnote) // Slightly smaller font for history
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.6))
                                    .lineSpacing(4)
                            }
                            .padding()
                            .background(neumorphicBackgroundStyle().opacity(0.8)) // Slightly muted background
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
                    composeMode = .reply(original: email) // Set compose mode for reply
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
                    composeMode = .forward(original: email) // Set compose mode for forward
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
        
        // Use the actual Gmail message ID
        let fetchedBody = await viewModel.fetchFullEmailBody(for: email.gmailMessageId) 
        
        isLoadingBody = false
        if let body = fetchedBody {
            fullBody = body
        } else {
            bodyErrorMessage = viewModel.errorMessage ?? "Could not load email content."
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

// MARK: - Preview
struct EmailDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock email with some history for preview
        let originalEmail = EmailDisplayData(
                                      gmailMessageId: "originalPreviewId", // Correct order
                                      sender: "Alice (Preview)",
                                      senderEmail: "alice.preview@example.com",
                                      recipient: "Preview Sender",
                                      subject: "Original Subject", 
                                      snippet: "Original snippet...", 
                                      body: "This is the body of the original email in the preview.",
                                      date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, 
                                      isRead: true, 
                                      previousMessages: nil)
        
        let previewEmail = EmailDisplayData(
                                     gmailMessageId: "replyPreviewId", // Correct order
                                     sender: "Preview Sender", 
                                     senderEmail: "sender.preview@example.com",
                                     recipient: "Alice (Preview)",
                                     subject: "Re: Original Subject", 
                                     snippet: "This is a longer preview snippet...", 
                                     body: "This is the full body text for the main preview email.\n\nIt replies to the email below.",
                                     date: Date(), 
                                     isRead: false,
                                     previousMessages: [originalEmail])
        
        NavigationView { // Wrap in NavigationView for preview
            EmailDetailView(email: previewEmail)
        }
    }
} 