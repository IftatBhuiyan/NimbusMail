import SwiftUI
import FirebaseAuth

struct AuthWrapper: View {
    @StateObject var viewModel = UserViewModel()
    @State private var showAuth = false
    
    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                ContentView()
                    .environmentObject(viewModel)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showAuth = true
                            }) {
                                Image(systemName: "person.circle")
                                    .font(.title2)
                            }
                        }
                    }
                    .sheet(isPresented: $showAuth) {
                        ProfileView(viewModel: viewModel)
                    }
            } else {
                AuthView(viewModel: viewModel)
            }
        }
        .onAppear {
            // Check current auth state on appear
            viewModel.isAuthenticated = Auth.auth().currentUser != nil
        }
    }
} 