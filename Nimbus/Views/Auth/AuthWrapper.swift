import SwiftUI
// import FirebaseAuth // Remove Firebase import

struct AuthWrapper: View {
    @StateObject var viewModel = UserViewModel()
    // Removed @State private var showAuth - profile is now presented from ContentView header
    
    // Set forceSkipAuth to false to enable the actual AuthView
    private let forceSkipAuth = false
    
    var body: some View {
        Group {
            // Always show ContentView if forceSkipAuth is true, otherwise check viewModel
            if forceSkipAuth || viewModel.isAuthenticated {
                ContentView()
                    .environmentObject(viewModel)
                 // Removed toolbar and sheet presentation for profile - handled in ContentView
            } else {
                AuthView(viewModel: viewModel)
            }
        }
        .onAppear {
            // If not forcing skip, check auth state
            // The viewModel now handles its own state via the listener
            // No need to check here directly
            // if !forceSkipAuth {
            //     viewModel.isAuthenticated = Auth.auth().currentUser != nil
            // }
        }
    }
} 