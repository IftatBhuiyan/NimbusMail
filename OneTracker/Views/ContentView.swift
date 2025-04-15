//
//  ContentView.swift
//  OneTracker
//
//  Created by Iftat Bhuiyan on 4/8/25.
//

import SwiftUI
import SwiftData

// MARK: - Email Data Structure for Display
struct EmailDisplayData: Identifiable, Hashable {
    let id = UUID()
    let gmailMessageId: String // Actual ID from Gmail API
    let threadId: String? // Gmail thread ID
    let messageIdHeader: String? // Value of the Message-ID header
    let referencesHeader: String? // Value of the References header
    let sender: String // Name for Inbox view
    let senderEmail: String? // Full email for Detail view
    let recipient: String?
    let subject: String
    let snippet: String
    let body: String
    let date: Date
    var isRead: Bool = false
    var previousMessages: [EmailDisplayData]?
    let accountEmail: String // Add this line to store the account email
    var labelIds: [String]? // Add this line to store label IDs
    
    // Custom hash function if needed, especially if previousMessages is added
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Custom equality check
    static func == (lhs: EmailDisplayData, rhs: EmailDisplayData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Main Content View (Email Inbox)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var viewModel: UserViewModel
    @State private var showingProfileSheet = false
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var isSideMenuShowing = false // State for side menu
    @State private var showingAddAccountSheet = false // State for Add Account sheet
    @FocusState private var isSearchFieldFocused: Bool // Add FocusState for search field
    @State private var composeMode: ComposeMode? = nil // State to trigger compose sheet
    @State private var displayedEmails: [EmailDisplayData] = [] // State for debounced results
    @State private var searchTask: Task<Void, Never>? = nil // Task for debouncing

    // Remove local mock emails - use viewModel.inboxEmails instead
    // @State private var mockEmails: [MockEmail] = [...] 

    // Computed property now just filters viewModel's emails
    var filteredEmails: [EmailDisplayData] {
        if searchText.isEmpty {
            return viewModel.inboxEmails // Use viewModel data source
        } else {
            // Use the recursive search function on viewModel's emails
            return viewModel.inboxEmails.filter { email in
                emailContainsText(email, searchText)
            }
        }
    }
    
    // Recursive function to search within email threads
    private func emailContainsText(_ email: EmailDisplayData, _ text: String) -> Bool {
        let lowercasedText = text.localizedLowercase
        
        // Check current email fields (sender, subject, and snippet)
        if email.sender.localizedLowercase.contains(lowercasedText) ||
           email.subject.localizedLowercase.contains(lowercasedText) ||
           email.snippet.localizedLowercase.contains(lowercasedText) {
            return true
        }
        
        // Check optional fields if they exist
        if let senderEmail = email.senderEmail, senderEmail.localizedLowercase.contains(lowercasedText) {
             return true
        }
        if let recipient = email.recipient, recipient.localizedLowercase.contains(lowercasedText) {
             return true
        }
        
        // Recursively check previous messages
        if let history = email.previousMessages {
            for previousEmail in history {
                if emailContainsText(previousEmail, text) {
                    return true // Found in history
                }
            }
        }
        
        // Text not found in this email or its history
                     return false
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .leading) { // Outer ZStack for side menu
                // Main Content ZStack (renamed innerZStack for clarity if needed)
                ZStack(alignment: .bottomTrailing) {
                    neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)

                    VStack(spacing: 0) {
                        // Header HStack - Restructured
                        HStack {
                            // Hamburger Menu (Only shown when search is NOT active)
                            if !isSearchActive {
                                Button {
                                    withAnimation(.easeInOut) {
                                        isSideMenuShowing.toggle()
                                    }
                                } label: {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.title2)
                                        .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                }
                                .frame(width: 44, height: 44)
                                .transition(.opacity) // Add transition
                            }
                            
                            Spacer()
                            
                            // Content Area (Title or Search Bar)
                            if isSearchActive {
                                // Search Bar HStack
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                    TextField("Search", text: $searchText)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .focused($isSearchFieldFocused)
                                    if !searchText.isEmpty {
                                        Button {
                                            searchText = ""
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                                .background(neumorphicBackgroundStyle())
                                .transition(.move(edge: .leading).combined(with: .opacity)) // Adjust transition
                            } else {
                                // Inbox Title (Only shown when search is NOT active)
                                Text("Inbox")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                    .transition(.opacity) // Add transition
                            }

                            Spacer()

                            // Search Activation/Deactivation Button (Always visible)
                            Button {
                                withAnimation {
                                    // If search is currently active, unfocus before toggling
                                    if isSearchActive {
                                        isSearchFieldFocused = false
                                    }
                                    isSearchActive.toggle()
                                    if isSearchActive {
                                         searchText = "" // Clear text when activating
                                         // Delay focus slightly after animation starts
                                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                             isSearchFieldFocused = true 
                                         }
                                     }
                                }
                            } label: {
                                Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                            }
                             .frame(width: 44, height: 44)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 8)
                        .frame(height: 50)

                        ScrollView {
                            // Show progress indicator when fetching
                            if viewModel.isFetchingEmails && displayedEmails.isEmpty { // Show initial fetch progress
                                ProgressView()
                                    .padding()
                            } else if displayedEmails.isEmpty && !viewModel.isFetchingEmails { // Check displayedEmails
                                // Show empty state message (adjust if needed based on search)
                                Text(searchText.isEmpty ? "Inbox is empty" : "No results found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                LazyVStack(spacing: 15) {
                                    // Iterate over displayedEmails (state variable)
                                    ForEach(displayedEmails) { email in 
                                        NavigationLink(destination: EmailDetailView(email: email)) {
                                            EmailRowView(email: email)
                                                .background(neumorphicBackgroundStyle())
                                                .onAppear { // Trigger pagination check
                                                    viewModel.fetchMoreEmailsIfNeeded(currentItem: email)
                                                }
                                        }
                                        .buttonStyle(.plain)
                                        // Remove the tap gesture that marks local mock data as read
                                        // .simultaneousGesture(TapGesture().onEnded { ... })
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 28)
                                .padding(.bottom, 80)
                            }
                        }
                        // Add refreshable modifier here
                        .refreshable { 
                            print("Pull to refresh triggered. Fetching emails...")
                            cancelSearchTask() // Cancel any pending search
                            viewModel.fetchAllInboxMessages() // Trigger full refresh
                            // Update displayed emails after fetch completes (handled by onAppear/onChange)
                        }
                    }

                    // Floating Action Button
                    FloatingActionButton {
                        print("Compose Email Tapped")
                        composeMode = .new // Set the compose mode to trigger the sheet
                    }
                    .padding()
                }
                .navigationBarHidden(true)
                // Disable main content interaction when menu is showing
                .disabled(isSideMenuShowing)
                // Darken main content when menu is showing
                .overlay {
                    if isSideMenuShowing {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isSideMenuShowing = false
                                }
                            }
                    }
                }

                // Side Menu (conditionally displayed)
                if isSideMenuShowing {
                    // Pass the necessary bindings
                    SideMenuView(isShowing: $isSideMenuShowing, 
                                 showingAddAccountSheet: $showingAddAccountSheet)
                        .frame(width: UIScreen.main.bounds.width * 0.9) // Use 90% width 
                        .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all))
                        .transition(.move(edge: .leading))
                        .zIndex(1) 
                }
            }
        }
        .onAppear { // Fetch emails when the view appears
            // Initial load or if coming back to the view
            updateDisplayedEmails(searchText: searchText)
        }
        // --- Add onChange for debouncing --- 
        .onChange(of: searchText) { newValue in
            // Cancel the previous task if it exists
            cancelSearchTask()
            
            // Start a new task to filter after a delay
            searchTask = Task {
                var finalResults: [EmailDisplayData] = []
                do {
                    // Wait for 300 milliseconds
                    try await Task.sleep(nanoseconds: 300_000_000)
                    
                    // --- Perform filtering in the background --- 
                    if newValue.isEmpty {
                        finalResults = viewModel.inboxEmails
                    } else {
                        finalResults = viewModel.inboxEmails.filter { email in
                            emailContainsText(email, newValue)
                        }
                    }
                    // --- End filtering ---
                    
                    // Update the state on the main actor ONLY with the final result
                    await MainActor.run { 
                        // Check if task was cancelled before updating state
                        guard !Task.isCancelled else { return }
                        displayedEmails = finalResults
                    }
                } catch {
                    // Handle cancellation (Task.sleep throws CancellationError)
                    // Check if the error is specifically CancellationError
                    if !(error is CancellationError) {
                        print("An unexpected error occurred in search task: \(error)")
                    } else {
                        print("Search task cancelled.") // Keep this log for cancellations
                    }
                }
            }
        }
        // --- Update displayed emails when source changes --- 
        .onChange(of: viewModel.inboxEmails) { _ in
            // Update displayed emails if the source data changes (e.g., after fetch/pagination)
            // Keep current search text filtering applied
            updateDisplayedEmails(searchText: searchText)
        }
        // Add the sheet modifier for the Add Account view
        .sheet(isPresented: $showingAddAccountSheet) {
            // Placeholder for AddAccountProviderView
            AddAccountProviderView()
                .environmentObject(viewModel)
        }
        // Add sheet modifier for ComposeEmailView
        .sheet(item: $composeMode) { mode in
            ComposeEmailView(mode: mode)
                 .environmentObject(viewModel)
                 .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all))
        }
        .environmentObject(viewModel)
    }
    
    // --- Helper Functions --- 
    private func updateDisplayedEmails(searchText: String) {
        if searchText.isEmpty {
            displayedEmails = viewModel.inboxEmails
        } else {
            displayedEmails = viewModel.inboxEmails.filter { email in
                emailContainsText(email, searchText)
            }
        }
    }
    
    private func cancelSearchTask() {
        searchTask?.cancel()
        searchTask = nil
    }
    // --- End Helper Functions ---
    
    private func neumorphicBackgroundStyle() -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(neumorphicBackgroundColor)
            .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
            .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
}

// MARK: - Email Row View
struct EmailRowView: View {
    let email: EmailDisplayData

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Circle()
                .fill(email.isRead ? Color.clear : Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(email.sender)
                        .font(.headline)
                        .fontWeight(email.isRead ? .regular : .semibold)
                        .foregroundColor(Color(hex: "0D2750").opacity(0.9))
                    Spacer()
                    Text(formatDate(email.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(email.subject)
                    .font(.subheadline)
                    .fontWeight(email.isRead ? .regular : .semibold)
                    .foregroundColor(email.isRead ? .secondary : Color(hex: "0D2750").opacity(0.8))
                    .lineLimit(1)
                Text(email.snippet)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
        .padding()
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
                 let formatter = DateFormatter()
                 formatter.dateFormat = "EEE"
                 return formatter.string(from: date)
            } else {
                return date.formatted(date: .numeric, time: .omitted)
            }
        }
    }
}

// Floating Action Button (Re-added)
struct FloatingActionButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .resizable()
                .frame(width: 24, height: 24)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
                .neumorphicDropShadow()
                .shadow(radius: 5)
        }
    }
}

// Removed TransactionRow View (no longer needed here)
// Removed PeriodSelectorView struct (no longer needed)
// Removed CustomDateRangePicker struct (no longer needed)

// Removed SuggestionData struct (finance specific)

