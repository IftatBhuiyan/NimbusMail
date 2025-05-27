import SwiftUI
// import FirebaseAuth // Remove Firebase import

struct AuthWrapper: View {
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var userViewModel = UserViewModel() // Initialize here
    @Environment(\.modelContext) private var modelContext // Access ModelContext
    
    // Set forceSkipAuth to false to enable the actual AuthView
    private let forceSkipAuth = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !userViewModel.isAuthenticated {
                Text("Offline Mode: Showing cached data. Sign in to sync.")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
            }
            Group {
                if forceSkipAuth || userViewModel.isAuthenticated {
                    ContentView()
                        .environmentObject(userViewModel)
                } else {
                    AuthView(viewModel: userViewModel)
                        .environmentObject(userViewModel)
                }
            }
        }
        .onAppear {
            userViewModel.setupModelContext(modelContext)
            
            // No need to call authService.checkAuthenticationState()
            // AuthenticationService handles its state internally via its listener.
        }
        // Listen to changes in authentication state from authService
        // and update UserViewModel's isAuthenticated accordingly.
        .onReceive(authService.$currentUser) { supabaseUser in // Explicitly type or let Swift infer User?
            let isAuthenticated = (supabaseUser != nil)
            if userViewModel.isAuthenticated != isAuthenticated {
                userViewModel.isAuthenticated = isAuthenticated
                if isAuthenticated {
                    userViewModel.userEmail = supabaseUser?.email // Should now work as supabaseUser is User?
                    userViewModel.userName = supabaseUser?.userMetadata["full_name"] as? String ?? supabaseUser?.userMetadata["name"] as? String
                    // UserViewModel's loadAccounts will be called by its own internal auth state listener now
                } else {
                    // Clear user-specific data on logout
                    userViewModel.clearUserSession() // Ensure this method exists in UserViewModel
                }
            }
        }
    }
} 