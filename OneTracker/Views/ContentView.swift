//
//  ContentView.swift
//  OneTracker
//
//  Created by Iftat Bhuiyan on 4/8/25.
//

import SwiftUI
import SwiftData

// MARK: - Mock Email Data Structure
struct MockEmail: Identifiable, Hashable {
    let id = UUID()
    let sender: String // Name for Inbox view
    let senderEmail: String? // Full email for Detail view
    let recipient: String?
    let subject: String
    let snippet: String
    let body: String
    let date: Date
    var isRead: Bool = false
    let previousMessages: [MockEmail]?
    
    // Custom hash function if needed, especially if previousMessages is added
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Custom equality check
    static func == (lhs: MockEmail, rhs: MockEmail) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Main Content View (Email Inbox)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var viewModel: UserViewModel
    @State private var mockEmails: [MockEmail] = [
        // --- Start of Conversation Thread ---
        MockEmail(sender: "user@example.com", // Latest reply from user to Alice
                  senderEmail: "user@example.com", // Add sender email
                  recipient: "Alice", // Keep recipient as name/address as needed for display
                  subject: "Re: Meeting Notes", 
                  snippet: "Thanks for sending these over, Alice! Looks good.", 
                  body: "Hi Alice,\n\nThanks for sending the meeting notes. Everything looks correct to me.\n\nBest,\nUser",
                  date: Calendar.current.date(byAdding: .minute, value: -30, to: Date())!, // 30 mins ago
                  isRead: true, 
                  previousMessages: [ // Include the previous message(s) here
                    MockEmail(sender: "Alice", // Original email from Alice
                              senderEmail: "alice.m@example.com", // Add sender email
                              recipient: "user@example.com",
                              subject: "Meeting Notes", 
                              snippet: "Here are the notes from today's meeting...", 
                              body: "Hi Team,\n\nHere are the key takeaways from our meeting today:\n- Finalized the Q3 roadmap.\n- Discussed resource allocation for Project Phoenix.\n- Agreed on the new reporting structure.\n\nPlease review the attached document for full details.\n\nBest,\nAlice",
                              date: Calendar.current.date(byAdding: .hour, value: -1, to: Date())!, // 1 hour ago
                              isRead: true, 
                              previousMessages: nil) // Original message has no previous messages
                  ]
        ),
        // --- End of Conversation Thread ---
        
        MockEmail(sender: "Bob Johnson", 
                  senderEmail: "bob.j@work.com", // Add sender email
                  recipient: "user@example.com",
                  subject: "Project Update", 
                  snippet: "Quick update on the Alpha project progress.", 
                  body: "Hello,\n\nJust a quick update on the Alpha project. We've completed the initial design phase and are moving into development next week. The timeline is still on track. Let me know if you have any questions.\n\nThanks,\nBob",
                  date: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!, isRead: true, previousMessages: nil),
        MockEmail(sender: "Newsletter",
                  senderEmail: "deals@company-news.com", // Add sender email
                  recipient: "user@example.com",
                  subject: "Weekly Deals", 
                  snippet: "Don't miss out on our exclusive weekly offers!", 
                  body: "This week's specials include:\n- 20% off all electronics\n- Free shipping on orders over $50\n- Exclusive access to new arrivals\n\nClick here to shop now! Offers expire Sunday.",
                  date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, isRead: false, previousMessages: nil), 
        MockEmail(sender: "Charlie", 
                  senderEmail: "charlie.d@personal.net", // Add sender email
                  recipient: "user@example.com",
                  subject: "Question about report", 
                  snippet: "Had a quick question regarding the Q1 report figures.", 
                  body: "Hi,\n\nI was looking over the Q1 report and had a question about the sales figures on page 5. Could we schedule a quick chat to discuss?\n\nBest,\nCharlie",
                  date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, isRead: true, previousMessages: nil),
        MockEmail(sender: "Support Team", 
                  senderEmail: "support@onetracker.app", // Add sender email
                  recipient: "user@example.com",
                  subject: "Your Ticket #12345", 
                  snippet: "We have received your support request and will...", 
                  body: "Dear User,\n\nThank you for contacting support. We have received your request (Ticket #12345) regarding login issues. A support representative will review your ticket and respond within 24 hours.\n\nSincerely,\nThe Support Team",
                  date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, isRead: true, previousMessages: nil),
        MockEmail(sender: "Marketing Dept.", 
                  senderEmail: "marketing@onetracker.app", // Add sender email
                  recipient: "user@example.com",
                  subject: "New Product Launch!", 
                  snippet: "Introducing the latest innovation from OneTracker!", 
                  body: "Get ready! OneTracker is thrilled announce the launch of our revolutionary new email feature, designed to streamline your inbox like never before. Experience seamless integration and unparalleled efficiency. Learn more on our website!",
                  date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, isRead: false, previousMessages: nil)
    ]
    @State private var showingProfileSheet = false
    @State private var isSearchActive = false
    @State private var searchText = ""

    var filteredEmails: [MockEmail] {
        if searchText.isEmpty {
            return mockEmails
        } else {
            // Use the recursive search function in the filter
            return mockEmails.filter { email in
                emailContainsText(email, searchText)
            }
        }
    }
    
    // Recursive function to search within email threads
    private func emailContainsText(_ email: MockEmail, _ text: String) -> Bool {
        let lowercasedText = text.localizedLowercase
        
        // Check current email fields
        if email.sender.localizedLowercase.contains(lowercasedText) ||
           email.subject.localizedLowercase.contains(lowercasedText) ||
           email.body.localizedLowercase.contains(lowercasedText) {
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
            ZStack(alignment: .bottomTrailing) {
                    neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)

                    VStack(spacing: 0) {
                    HStack {
                        if isSearchActive {
                        HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search Mail", text: $searchText)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                    .accentColor(Color.blue)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    
                                if !searchText.isEmpty {
                            Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .modifier(NeumorphicInnerShadow())
                            
                            Button("Cancel") {
                                withAnimation {
                                    isSearchActive = false
                                    searchText = ""
                                }
                            }
                            .foregroundColor(.blue)
                            .padding(.leading, 8)
                            
                        } else {
                            Button {
                                showingProfileSheet = true
                            } label: {
                                Image(systemName: "person.crop.circle")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                            }
                            .frame(width: 44, height: 44)
                            
                            Spacer()
                            
                            Text("Inbox")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                            
                            Spacer()
                            
                                Button {
                                withAnimation {
                                    isSearchActive = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                            }
                             .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 8)
                    .frame(height: 50)

                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(filteredEmails) { email in
                                NavigationLink(destination: EmailDetailView(email: email)) {
                                    EmailRowView(email: email)
                                        .background(neumorphicBackgroundStyle())
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                     if let index = mockEmails.firstIndex(where: { $0.id == email.id }) {
                                         mockEmails[index].isRead = true
                                     }
                                })
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 28)
                        .padding(.bottom, 80)
                    }
                }

                FloatingActionButton {
                    print("Compose Email Tapped")
                }
                .padding()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingProfileSheet) {
                ProfileView(viewModel: viewModel)
                    .environmentObject(viewModel)
                    .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all))
            }
        }
    }
    
    private func neumorphicBackgroundStyle() -> some View {
        RoundedRectangle(cornerRadius: 15)
             .fill(neumorphicBackgroundColor)
             .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
             .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
}

// MARK: - Email Row View
struct EmailRowView: View {
    let email: MockEmail

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

// Preview Provider - Needs updating if you want previews for the new structure
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Transaction.self, configurations: config)

        let userViewModel = UserViewModel()
        userViewModel.isAuthenticated = true

        return ContentView()
            .modelContainer(container)
            .environmentObject(userViewModel)
    }
}

// Keep Neumorphism helpers if they are not in a separate utility file yet
// ... (Color(hex:), neumorphicBackgroundColor, NeumorphicShadow, etc.) ...

// Removed SuggestionData struct (finance specific)

