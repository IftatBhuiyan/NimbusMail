import SwiftUI
import Supabase

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
    
    // State for Settings Sheet
    @State private var showingSettingsSheet = false 
    
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
            VStack(alignment: .leading, spacing: 5) { // Reduced overall spacing
                // 1. Header
                Text("Lunar Mail")
                    .font(.title).fontWeight(.bold) // Slightly smaller title
                    .foregroundColor(neumorphicTextColor)
                    .padding(.leading)
                    .padding(.top, 20) // Added top padding
                    .padding(.bottom, 5) // Reduced bottom padding
                
                Divider().padding(.bottom, 5)

                // --- Top Level Items --- 
                Group {
                    // 2. All Inboxes Button
                    Button {
                        viewModel.selectedAccountFilter = nil
                        viewModel.selectedLabelFilter = nil // Ensure label filter is also cleared
                        withAnimation { isShowing = false } 
                        print("Selected Filter: All Inboxes")
                        
                        // Explicitly trigger a fetch for all inboxes
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: {
                        Label("All Inboxes", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    
                    Divider().padding(.vertical, 5) // Reduced divider padding

                    // 3. Individual Accounts
                    ForEach(viewModel.addedAccounts) { account in 
                        DisclosureGroup(
                            isExpanded: Binding(
                                // Read from ViewModel's state
                                get: { viewModel.expandedAccountIDs.contains(account.id) }, 
                                // Write to ViewModel's state
                                set: { isExpanding in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if isExpanding { viewModel.expandedAccountIDs.insert(account.id) } 
                                        else { viewModel.expandedAccountIDs.remove(account.id) }
                                    }
                                }
                            ),
                            content: { // Display fetched labels
                                VStack(alignment: .leading, spacing: 4) { // Reduced spacing for labels
                                    if viewModel.isFetchingLabels[account.emailAddress] == true {
                                        ProgressView()
                                            .padding(.leading, 15)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else if let labels = viewModel.labelsByAccount[account.emailAddress], !labels.isEmpty {
                                        // Define the desired order of label IDs (case-insensitive comparison)
                                        let preferredOrder: [String] = [
                                            "INBOX",
                                            "CATEGORY_PRIMARY",
                                            "STARRED",
                                            "IMPORTANT",
                                            "SENT",
                                            "DRAFT",
                                            "SNOOZED",
                                            "SCHEDULED",
                                            "SPAM",
                                            "TRASH",
                                            "ALL"
                                        ]
                                        let preferredOrderSet = Set(preferredOrder) // Use Set for faster lookup

                                        let filteredLabels = labels.filter { label in
                                            // Only keep labels that are in the preferredOrder list
                                            guard let id = label.identifier?.uppercased() else { return false }
                                            return preferredOrderSet.contains(id)
                                        }.sorted { label1, label2 in
                                           // Sorting logic remains the same, but only applies to preferred labels
                                           let id1 = label1.identifier?.uppercased() ?? ""
                                           let id2 = label2.identifier?.uppercased() ?? ""
                                           
                                           // Find index in the original array to maintain defined order
                                           let index1 = preferredOrder.firstIndex(of: id1)
                                           let index2 = preferredOrder.firstIndex(of: id2)
                                           
                                           // Since we filtered beforehand, both should ideally be found
                                           // Handle potential nil just in case, but prioritize index order
                                           if let index1 = index1, let index2 = index2 {
                                               return index1 < index2
                                           } else if index1 != nil {
                                               return true // label1 is preferred, comes first
                                           } else if index2 != nil {
                                               return false // label2 is preferred, comes first
                                           } else {
                                               // Should not happen if filter worked, but fallback to name
                                               return (label1.name ?? "") < (label2.name ?? "")
                                           }
                                        }
                                        
                                        ForEach(filteredLabels, id: \.identifier) { label in
                                            Button {
                                                viewModel.selectedAccountFilter = account.emailAddress // Set account context
                                                viewModel.selectedLabelFilter = label.identifier
                                                // Trigger fetch for the new filter
                                                Task { 
                                                    await viewModel.fetchMessagesForCurrentFilter()
                                                }
                                                withAnimation { isShowing = false } // Dismiss menu
                                                print("Tapped label: \(label.name ?? "N/A") (ID: \(label.identifier ?? "N/A"))")
                                            } label: {
                                                // Simple Label display (can customize with icons)
                                                Label((label.name ?? "Unknown Label").capitalized, systemImage: labelIcon(for: label.identifier))
                                                    .font(.subheadline)
                                            }
                                            .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                                            .padding(.leading, 15)
                                        }
                                    } else {
                                        Text("(No folders found)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 15)
                                    }
                                    
                                    // --- Add Static All Mail Button Here (After Fetched Labels) --- 
                                    Button {
                                        viewModel.selectedAccountFilter = account.emailAddress // Ensure account context
                                        viewModel.selectedLabelFilter = nil // nil signifies All Mail
                                        withAnimation { isShowing = false } // Close menu
                                        print("Tapped label: All Mail (nil) for \(account.emailAddress)")
                                        
                                        // Explicitly trigger a fetch for this account's All Mail
                                        Task {
                                            await viewModel.fetchMessagesForCurrentFilter()
                                        }
                                    } label: {
                                        Label("All Mail", systemImage: "tray.full.fill") // Use suitable icon
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                                    .padding(.leading, 15) // Indent like other labels
                                    // --- End Static All Mail Button ---
                                }
                                .padding(.leading, 10)
                                .padding(.vertical, 5) // Reduced vertical padding
                                .onAppear { 
                                    // Only trigger fetch if we don't have labels yet or the last fetch was a long time ago
                                    if viewModel.labelsByAccount[account.emailAddress]?.isEmpty ?? true {
                                        viewModel.fetchLabels(for: account)
                                    } else {
                                        // If we already have labels, fetch in the background for updates
                                        // but don't trigger immediately to prevent UI flickering
                                        Task {
                                            // Small delay to prevent immediate fetch when toggling disclosure group
                                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                            viewModel.fetchLabels(for: account)
                                        }
                                    }
                                }
                            },
                            label: { 
                                Button {
                                    viewModel.selectedAccountFilter = account.emailAddress
                                    viewModel.selectedLabelFilter = "INBOX"
                                    withAnimation { isShowing = false } 
                                    print("Selected Filter: \(account.emailAddress), Label: INBOX")
                                    
                                    // Explicitly trigger a fetch for this account's inbox
                                    Task {
                                        await viewModel.fetchMessagesForCurrentFilter()
                                    }
                                } label: {
                                     Label(account.emailAddress, systemImage: "envelope.fill")
                                         .font(.subheadline) // Make account labels slightly smaller
                                }
                                .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                            }
                        )
                        .accentColor(neumorphicTextColor)
                        .padding(.vertical, 0) // Remove vertical padding around disclosure group
                    }
                    
                    // 4. Add Account Button
                    Button {
                        print("Add Account Tapped")
                        showingAddAccountSheet = true
                        withAnimation { isShowing = false } 
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                    .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    .padding(.top, 5) // Reduced top padding
                    
                    Divider().padding(.vertical, 5) // Reduced divider padding
                    
                    // 5. Combined Categories (Static for now)
                    Button { 
                        // Set up for combined view of STARRED across all accounts
                        viewModel.selectedAccountFilter = nil // All accounts
                        viewModel.selectedLabelFilter = "STARRED"
                        withAnimation { isShowing = false }
                        print("Selected Filter: All Accounts, Label: STARRED")
                        
                        // Trigger fetch for this filter
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: { Label("Pinned", systemImage: "pin.fill") }.buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    
                    Button { 
                        // Set up for combined view of UNREAD across all accounts
                        viewModel.selectedAccountFilter = nil // All accounts
                        viewModel.selectedLabelFilter = "UNREAD"
                        withAnimation { isShowing = false }
                        print("Selected Filter: All Accounts, Label: UNREAD")
                        
                        // Trigger fetch for this filter
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: { Label("Unread", systemImage: "envelope.badge.fill") }.buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    
                    Button { 
                        // Set up for combined view of SENT across all accounts
                        viewModel.selectedAccountFilter = nil // All accounts
                        viewModel.selectedLabelFilter = "SENT"
                        withAnimation { isShowing = false }
                        print("Selected Filter: All Accounts, Label: SENT")
                        
                        // Trigger fetch for this filter
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: { Label("Sent", systemImage: "paperplane.fill") }.buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    
                    Button { 
                        // Set up for combined view of DRAFT across all accounts
                        viewModel.selectedAccountFilter = nil // All accounts
                        viewModel.selectedLabelFilter = "DRAFT"
                        withAnimation { isShowing = false }
                        print("Selected Filter: All Accounts, Label: DRAFT")
                        
                        // Trigger fetch for this filter
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: { Label("Drafts", systemImage: "doc.fill") }.buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    
                    Button { 
                        // Set up for combined view of CATEGORY_UPDATES across all accounts
                        viewModel.selectedAccountFilter = nil // All accounts
                        viewModel.selectedLabelFilter = "CATEGORY_UPDATES"
                        withAnimation { isShowing = false }
                        print("Selected Filter: All Accounts, Label: CATEGORY_UPDATES")
                        
                        // Trigger fetch for this filter
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: { Label("Scheduled", systemImage: "clock.fill") }.buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    
                    Button { 
                        // Set up for combined view of CATEGORY_PERSONAL across all accounts
                        viewModel.selectedAccountFilter = nil // All accounts
                        viewModel.selectedLabelFilter = "CATEGORY_PERSONAL"
                        withAnimation { isShowing = false }
                        print("Selected Filter: All Accounts, Label: CATEGORY_PERSONAL")
                        
                        // Trigger fetch for this filter
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: { Label("Archive", systemImage: "archivebox.fill") }.buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                    
                    Button { 
                        // Set up for combined view of TRASH across all accounts
                        viewModel.selectedAccountFilter = nil // All accounts
                        viewModel.selectedLabelFilter = "TRASH"
                        withAnimation { isShowing = false }
                        print("Selected Filter: All Accounts, Label: TRASH")
                        
                        // Trigger fetch for this filter
                        Task {
                            viewModel.fetchAllInboxMessages()
                        }
                    } label: { Label("Trash", systemImage: "trash.fill") }.buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false))
                }
                .padding(.horizontal)
                
                Spacer() 
                 
            } // End Main VStack
            
            // Settings/Logout section at the very bottom
            VStack(alignment: .leading, spacing: 0) { 
                 Divider().padding(.bottom, 10) // Reduced padding
                 Button {
                    showingSettingsSheet = true // Set state to show sheet
                 } label: {
                    Label("Settings", systemImage: "gear")
                 }
                 .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false)) 
                 .padding(.bottom, 5) // Reduced padding
                 
                 Button {
                     // Wrap async call in a Task and use await
                     Task {
                         await viewModel.signOut()
                     }
                 } label: {
                     Label("Logout", systemImage: "arrow.right.square")
                 }
                 .buttonStyle(NeumorphicSideMenuItemStyle(isDisclosureGroup: false)) 
            }
            .padding(.horizontal) 
            .padding(.bottom, 20) // Reduced bottom padding
        }
        // Add the sheet modifier to the outer ScrollView or VStack
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView() // Present the SettingsView
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

    // Helper to get an appropriate icon for a label ID
    private func labelIcon(for identifier: String?) -> String {
        guard let id = identifier?.uppercased() else { return "folder" }
        switch id {
            case "INBOX": return "tray.fill"
            case "SENT": return "paperplane.fill"
            case "DRAFT": return "doc.fill"
            case "SPAM": return "xmark.bin.fill"
            case "TRASH": return "trash.fill"
            case "IMPORTANT": return "exclamationmark.circle.fill"
            case "STARRED": return "star.fill"
            // Add more system labels if needed (e.g., CATEGORY_SOCIAL, etc.)
            default: return "folder" // Default for user labels
        }
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
        .padding(.vertical, 10) // Reduced vertical padding within items
        .padding(.horizontal, 0) 
        .background(
            ZStack {
                Color.clear 
                
                if configuration.isPressed {
                     RoundedRectangle(cornerRadius: 8) // Slightly smaller corner radius
                        .fill(Color(hex: "E0E5EC")) 
                        .stroke(Color(hex: "E0E5EC"), lineWidth: 4) 
                        .shadow(color: darkPressedShadowColor, radius: 3, x: 3, y: 3) 
                        .shadow(color: lightPressedShadowColor, radius: 3, x: -3, y: -3) 
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        )
        .cornerRadius(8) // Slightly smaller corner radius
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0) 
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// struct SideMenuView_Previews: PreviewProvider { ... } // Remove this entire block 
