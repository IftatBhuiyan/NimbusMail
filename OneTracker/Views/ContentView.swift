//
//  ContentView.swift
//  OneTracker
//
//  Created by Iftat Bhuiyan on 4/8/25.
//

import SwiftUI
import SwiftData

// Main Content View (Will become Email Inbox View)
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext // Keep for potential future use or other data
    // Removed @Query for Transactions
    // Removed finance-specific @State variables (activeSheet, selectedPeriod, etc.)
    @EnvironmentObject var viewModel: UserViewModel // Keep UserViewModel

    // Removed finance-specific computed properties (uniqueMerchantNames, bankNames, titleText, totals, groupedTransactions, sectionOrder)

    var body: some View {
        TabView {
            // Email Inbox Tab (Formerly Finances)
            NavigationView {
                ZStack(alignment: .bottomTrailing) { // Keep ZStack for FAB layering
                    neumorphicBackgroundColor.edgesIgnoringSafeArea(.all) // Keep background

                    VStack(spacing: 0) {
                        // Simplified Header
                        HStack {
                            Text("Inbox") // Simple Title for now
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "0D2750").opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Placeholder for potential future header buttons (e.g., Search)
                            Spacer() 
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 8)

                        // Placeholder for Email List
                        ScrollView { // Keep ScrollView structure
                            VStack {
                                Text("Email list will go here...")
                                    .foregroundColor(Color(hex: "0D2750").opacity(0.7))
                                    .padding()
                                Spacer() // Keep spacer to push content up
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow placeholder to expand
                        }
                        .padding(.top, 8) // Add padding above the placeholder content
                    }
                    .background( // Keep neumorphic container style for the main content area
                         RoundedRectangle(cornerRadius: 20)
                             .fill(neumorphicBackgroundColor)
                             .shadow(color: darkInnerShadowColor, radius: darkInnerShadowBlur, x: darkInnerShadowX, y: darkInnerShadowY)
                             .shadow(color: lightInnerShadowColor, radius: lightInnerShadowBlur, x: lightInnerShadowX, y: lightInnerShadowY)
                     )
                     .clipShape(RoundedRectangle(cornerRadius: 20))
                     .padding() // Keep padding around the container

                    // Floating Action Button (Action cleared, ready for Compose)
                    FloatingActionButton {
                        // TODO: Implement action for composing new email
                        print("Compose Email Tapped")
                    }
                    .padding()
                }
                .navigationBarHidden(true) // Keep default nav bar hidden
                // Removed .sheet modifiers for add/edit/period
            }
            .tabItem {
                // Update icon for email
                Label("Inbox", systemImage: "envelope.fill")
            }

            // Profile Tab (Keep)
            NavigationView { 
                 ProfileView(viewModel: viewModel)
                    .navigationTitle("Profile")
                    .environmentObject(viewModel)
            }
            .tabItem {
                 Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
        .accentColor(.blue)
    }

    // Removed finance-specific functions (addTransaction, updateTransaction, deleteTransaction)
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
                .neumorphicDropShadow() // Apply neumorphic shadow
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
        // Setup minimal container/viewmodel for preview
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Transaction.self, configurations: config) // Keep Transaction temporarily if needed for container setup

        let userViewModel = UserViewModel()
        userViewModel.isAuthenticated = true

        return ContentView()
            .modelContainer(container) // Provide a container
            .environmentObject(userViewModel) // Provide the view model
    }
}

// Keep Neumorphism helpers if they are not in a separate utility file yet
// ... (Color(hex:), neumorphicBackgroundColor, NeumorphicShadow, etc.) ...

// Removed SuggestionData struct (finance specific)

