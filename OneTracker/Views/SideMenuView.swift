import SwiftUI

// REMOVE Mock Data Structures - They are now in EmailAccountModels.swift
/*
struct MailboxFolder: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct EmailAccount: Identifiable {
    let id = UUID()
    let emailAddress: String
    var folders: [MailboxFolder]
}
*/
// --- End Removal ---

struct SideMenuView: View {
    @EnvironmentObject var viewModel: UserViewModel // Keep for Logout action
    @Binding var isShowing: Bool // Binding to control the side menu visibility
    @Binding var showingAddAccountSheet: Bool // Binding to trigger add account sheet
    
    // Use state for expansion, but data comes from viewModel
    @State private var expandedAccounts: Set<UUID> = []
    
    // Neumorphic text color
    private let neumorphicTextColor = Color(hex: "0D2750").opacity(0.8)

    // --- Explicit Initializer --- 
    init(isShowing: Binding<Bool>, showingAddAccountSheet: Binding<Bool>) {
        self._isShowing = isShowing // Use underscore for bindings
        self._showingAddAccountSheet = showingAddAccountSheet
    }
    // --- End Explicit Initializer ---

    var body: some View {
        ScrollView { 
            VStack(alignment: .leading, spacing: 15) { // Keep overall vertical spacing
                // 1. Header
                Text("Lunar Mail")
                    .font(.largeTitle).fontWeight(.bold)
                    .foregroundColor(neumorphicTextColor)
                    .padding(.leading) // Add leading padding
                    .padding(.bottom, 10)
                
                Divider().padding(.bottom, 10)

                // --- Top Level Items --- 
                // Apply consistent leading padding here
                Group {
                    // 2. All Inboxes
                    Button {
                        print("Go to All Inboxes")
                    } label: {
                        Label("All Inboxes", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(NeumorphicSideMenuItemStyle()) 
                    
                    Divider().padding(.vertical, 10)

                    // 3. Individual Accounts (Use viewModel.addedAccounts)
                    // Use ForEach directly on viewModel.addedAccounts
                    ForEach(viewModel.addedAccounts) { account in 
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedAccounts.contains(account.id) },
                                set: { isExpanding in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isExpanding { expandedAccounts.insert(account.id) } 
                                        else { expandedAccounts.remove(account.id) }
                                    }
                                }
                            ),
                            content: { // Placeholder for Folders (Load dynamically later)
                                VStack(alignment: .leading) {
                                    // TODO: Load actual folders for the account
                                    Text("(Placeholder Inbox)").font(.subheadline).padding(.leading, 15)
                                    Text("(Placeholder Sent)").font(.subheadline).padding(.leading, 15)
                                }
                                .padding(.leading, 10)
                                .padding(.top, 5)
                            },
                            label: { 
                                 Label(account.emailAddress, systemImage: "envelope.fill")
                            }
                        )
                        .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: true)) 
                        .accentColor(neumorphicTextColor) 
                        .padding(.vertical, 5)
                    }
                    
                    // 4. Add Account Button
                    Button {
                        print("Add Account Tapped")
                        showingAddAccountSheet = true // Trigger the sheet
                        withAnimation {
                            isShowing = false // Optionally close side menu
                        }
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                    .buttonStyle(NeumorphicSideMenuItemStyle())
                    .padding(.top, 10)
                    
                    Divider().padding(.vertical, 10)
                    
                    // 5. Combined Categories (Static for now)
                    // TODO: Define these properly based on combined logic
                    Button { print("Go to Combined Inbox") } label: { Label("Inbox", systemImage: "tray.2.fill") }.buttonStyle(NeumorphicSideMenuItemStyle())
                    Button { print("Go to Combined Sent") } label: { Label("Sent", systemImage: "paperplane.fill") }.buttonStyle(NeumorphicSideMenuItemStyle())
                    Button { print("Go to Combined Drafts") } label: { Label("Drafts", systemImage: "doc.fill") }.buttonStyle(NeumorphicSideMenuItemStyle())
                }
                .padding(.horizontal) // Apply consistent horizontal padding to top-level items
                
                Spacer() // Pushes Settings/Logout down 
                 
            } // End Main VStack
             // Remove overall padding here: .padding()
            
            // Settings/Logout section at the very bottom
            VStack(alignment: .leading, spacing: 0) { 
                 Divider().padding(.bottom, 15)
                 Button {
                    print("Go to Settings")
                 } label: {
                    Label("Settings", systemImage: "gear")
                 }
                 .buttonStyle(NeumorphicSideMenuItemStyle()) 
                 .padding(.bottom, 10) 
                 
                 Button {
                     Task {
                         viewModel.signOut()
                     }
                 } label: {
                     Label("Logout", systemImage: "arrow.right.square")
                 }
                 .buttonStyle(NeumorphicSideMenuItemStyle()) 
            }
            .padding(.horizontal) // Match horizontal padding
            .padding(.bottom, 30) // Bottom padding
        }
    }
    
    // --- Reusable Neumorphic Background --- 
    // (Ensure these helpers are accessible or redefine them here if needed)
    private let neumorphicBackgroundColor = Color(hex: "E0E5EC") // Example color
    private let darkDropShadowColor = Color.black.opacity(0.2)
    private let lightDropShadowColor = Color.white.opacity(0.7)
    private var darkDropShadowX: CGFloat = 5
    private var darkDropShadowY: CGFloat = 5
    private var darkDropShadowBlur: CGFloat = 8
    private var lightDropShadowX: CGFloat = -3
    private var lightDropShadowY: CGFloat = -3
    private var lightDropShadowBlur: CGFloat = 5
    
    @ViewBuilder
    private func neumorphicBackgroundStyle(cornerRadius: CGFloat = 10) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
             .fill(neumorphicBackgroundColor)
             .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
             .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
    }
}

// --- Custom Button Style for Neumorphic Menu Items --- 
struct NeumorphicSideMenuItemStyle: ButtonStyle {
    var isDisclosureGroup: Bool = false
    private let neumorphicTextColor = Color(hex: "0D2750").opacity(0.8)
    private let darkPressedShadowColor = Color.black.opacity(0.1)
    private let lightPressedShadowColor = Color.white.opacity(0.9)

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundColor(neumorphicTextColor)
            Spacer()
        }
        .padding(.vertical) // Vertical padding only inside style
        .padding(.horizontal, 0) // Remove horizontal padding inside style
        .background(
            ZStack {
                Color.clear 
                if configuration.isPressed {
                     RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "E0E5EC")) 
                        .stroke(Color(hex: "E0E5EC"), lineWidth: 4) 
                        .shadow(color: darkPressedShadowColor, radius: 3, x: 3, y: 3) 
                        .shadow(color: lightPressedShadowColor, radius: 3, x: -3, y: -3) 
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        )
        .cornerRadius(10)
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0) 
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SideMenuView_Previews: PreviewProvider {
    static var previews: some View {
        // Add mock accounts to the preview view model
        let mockAccounts = [
             EmailAccount(emailAddress: "preview1@example.com", provider: "gmail"),
             EmailAccount(emailAddress: "preview2@work.com", provider: "exchange")
        ]
        let mockViewModel = UserViewModel(isAuthenticated: true,
                                        userEmail: "preview1@example.com", 
                                        userName: "Preview User",
                                        addedAccounts: mockAccounts) // Pass mock accounts
        
        SideMenuView(isShowing: .constant(true), showingAddAccountSheet: .constant(false))
            .environmentObject(mockViewModel)
            .background(Color(hex: "E0E5EC").edgesIgnoringSafeArea(.all)) // Use neumorphic bg
            .frame(width: 300) 
    }
} 