import SwiftUI
import FirebaseAuth

struct AuthWrapper: View {
    @StateObject var viewModel = UserViewModel()
    // Removed @State private var showAuth - profile is now presented from ContentView header
    
    // DEVELOPMENT ONLY: Force skip authentication
    private let forceSkipAuth = true 
    
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
            if !forceSkipAuth {
                viewModel.isAuthenticated = Auth.auth().currentUser != nil
            }
        }
    }
} 