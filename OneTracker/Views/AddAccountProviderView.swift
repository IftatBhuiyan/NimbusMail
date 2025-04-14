import SwiftUI
import GoogleSignIn // Import GoogleSignIn
import GoogleSignInSwift // For the SwiftUI button helper (optional but convenient)

struct AddAccountProviderView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: UserViewModel // For potential auth actions
    
    // Define provider options
    struct Provider: Identifiable {
        let id = UUID()
        let name: String
        let iconName: String // System name or asset name
        let iconColor: Color? // Optional specific color for icon bg
        let action: () -> Void
    }
    
    private let providers: [Provider] = [
        Provider(name: "Gmail", iconName: "google-logo", iconColor: .white) { print("Gmail Tapped") /* TODO: Start Google Sign In */ },
        Provider(name: "Outlook", iconName: "outlook-logo", iconColor: nil) { print("Outlook Tapped") },
        Provider(name: "Yahoo", iconName: "yahoo-logo", iconColor: Color(hex:"#6001D2")) { print("Yahoo Tapped") },
        Provider(name: "Office365", iconName: "office-logo", iconColor: nil) { print("Office365 Tapped") },
        Provider(name: "Exchange", iconName: "exchange-logo", iconColor: nil) { print("Exchange Tapped") },
        Provider(name: "iCloud", iconName: "icloud.fill", iconColor: nil) { print("iCloud Tapped") }, // SF Symbol example
        Provider(name: "OnMail", iconName: "onmail-logo", iconColor: nil) { print("OnMail Tapped") },
        Provider(name: "Aol", iconName: "aol-logo", iconColor: .black) { print("Aol Tapped") },
        Provider(name: "Hotmail", iconName: "envelope", iconColor: .orange) { print("Hotmail Tapped") }, // Placeholder
        Provider(name: "University", iconName: "graduationcap.fill", iconColor: .blue) { print("University Tapped") }, // SF Symbol example
        Provider(name: "Comcast", iconName: "comcast-logo", iconColor: nil) { print("Comcast Tapped") },
        Provider(name: "Other", iconName: "envelope.fill", iconColor: .blue) { print("Other Tapped") } // SF Symbol example
    ]
    
    // Layout grid columns
    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 20), count: 3)

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(providers) { provider in
                        if provider.name == "Gmail" {
                            // Use GoogleSignInButton for consistent styling (optional)
                             GoogleSignInButton(action: handleSignInButton)
                                .frame(width: 60, height: 60) // Adjust size if needed
                                .clipShape(Circle())
                                .shadow(radius: 3, x: 1, y: 2)
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)) // Optional border
                                .padding(.bottom, 5) // Add space for text below
                             Text(provider.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                        } else {
                            // Keep other providers as disabled buttons
                            Button {
                                print("\(provider.name) selected (not implemented)")
                            } label: {
                                VStack {
                                    ZStack {
                                        Circle()
                                            .fill(provider.iconColor ?? Color(.systemGray5)) 
                                            .frame(width: 60, height: 60)
                                            .shadow(radius: 3, x: 1, y: 2)
                                        
                                        if isSFSymbol(provider.iconName) {
                                             Image(systemName: provider.iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30, height: 30)
                                                .foregroundColor(provider.iconColor == .white || provider.iconColor == .black ? .primary.opacity(0.8) : .white) 
                                        } else {
                                            Image(provider.iconName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 35, height: 35) 
                                        }
                                    }
                                    
                                    Text(provider.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            .disabled(true) 
                            .opacity(0.5) 
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Add an Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Function to handle Google Sign In button tap
    private func handleSignInButton() {
      guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {return}

        let gmailReadOnlyScope = "https://www.googleapis.com/auth/gmail.readonly"
        // Add other scopes like modify or send if needed
        let gmailSendScope = "https://www.googleapis.com/auth/gmail.send"
        let gmailModifyScope = "https://www.googleapis.com/auth/gmail.modify"

        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil, // Optional: Email hint if known
            additionalScopes: [gmailReadOnlyScope, gmailSendScope, gmailModifyScope]) { signInResult, error in
                
            guard let result = signInResult else {
                // Handle error
                print("Error signing in: \(error?.localizedDescription ?? "Unknown error")")
                // Update UI or show error message
                viewModel.errorMessage = "Google Sign-In Failed: \(error?.localizedDescription ?? "Unknown error")"
                return
            }

            // --- Authentication Successful --- 
            
            // 1. Get user info
            let user = result.user
            let email = user.profile?.email
            let fullName = user.profile?.name
            print("Google User Signed In: \(fullName ?? "N/A") (\(email ?? "N/A"))")

            // 2. Get Tokens (IMPORTANT for API access)
            guard let idToken = user.idToken?.tokenString else {
                 print("Error: Missing ID Token")
                 viewModel.errorMessage = "Google Sign-In Failed: Missing ID Token"
                 return
            }
            // Access token is needed for API calls
            let accessToken = user.accessToken.tokenString
            // Refresh token might be needed for long-term access
            let refreshToken = user.refreshToken.tokenString

            // Assign unused tokens to _ to silence warnings for now
            _ = idToken
            _ = accessToken

            print("ID Token: [REDACTED]") // Don't log tokens in production
            print("Access Token: [REDACTED]") 
            print("Refresh Token: [REDACTED]")

            // --- Save Refresh Token to Keychain --- 
            if let userEmail = email, !refreshToken.isEmpty {
                let saveSuccessful = KeychainService.save(token: refreshToken, account: userEmail)
                if !saveSuccessful {
                    // Handle keychain save error (e.g., show an alert to the user)
                    print("Error: Failed to save refresh token to Keychain.")
                    viewModel.errorMessage = "Failed to securely save account credentials."
                    // Consider *not* dismissing if keychain save fails, as the user might need to retry
                    return // Prevent dismissing if save failed
                } else {
                    print("Successfully saved refresh token for \(userEmail)")
                }
            } else {
                 print("Error: Missing email or refresh token, cannot save to Keychain.")
                 viewModel.errorMessage = "Failed to retrieve necessary account credentials."
                 return // Prevent dismissing if data is missing
            }
            // --- End Keychain Save ---
            
            // --- Add Account to ViewModel ---
            if let userEmail = email {
                viewModel.addAccount(email: userEmail, provider: "gmail", refreshToken: refreshToken)
            } else {
                // This case should ideally not happen if Keychain save succeeded
                print("Error: Cannot add account to list because email is missing.")
            }
            // --- End Add Account ---
            
            // TODO: Store accessToken (maybe in memory or Keychain, consider its expiry)
            
            // For now, just print success
            print("Google Sign-In Successful! Ready to make API calls.")
            viewModel.errorMessage = nil // Clear any previous errors
                
            // Dismiss the sheet after successful sign-in AND keychain save
            dismiss()
        }
    }
    
    // Helper to check if a name likely corresponds to an SF Symbol
    private func isSFSymbol(_ name: String) -> Bool {
        // Basic check: SF Symbols often contain dots or are lowercase/camelCase
        // Asset names are often PascalCase or kebab-case without dots.
        // This is a heuristic and might need refinement.
        return name.contains(".") || name.allSatisfy { $0.isLowercase || $0.isNumber || $0 == Character(".") } 
    }
}

struct AddAccountProviderView_Previews: PreviewProvider {
    static var previews: some View {
        AddAccountProviderView()
            .environmentObject(UserViewModel(isAuthenticated: false, userEmail: nil, userName: nil))
    }
}

// --- Add Color(hex:) extension if not defined globally --- 
// extension Color { ... } 