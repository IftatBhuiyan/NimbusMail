import Foundation
// Remove Firebase imports
// import FirebaseAuth
// import FirebaseCore
import Supabase // Add Supabase
import Combine // Needed for Cancellable
import AuthenticationServices
import CryptoKit

// Authentication error types
enum AuthError: Error {
    case signInError(message: String)
    case signUpError(message: String)
    case signOutError(message: String)
    case userNotFound // May not be directly applicable, Supabase throws specific errors
    case invalidCredentials // Supabase errors cover this
    case resetPasswordError(message: String) // Added for password reset
    case appleSignInError(message: String) // Specific Apple sign-in error
    case unknown(message: String)
}

// Authentication service class using Supabase
@MainActor // Ensure @Published properties are updated on the main thread
class AuthenticationService: NSObject {
    static let shared = AuthenticationService()
    
    // Current nonce for Apple sign-in
    private var currentNonce: String?
    
    // Authentication state using Supabase User
    @Published var isUserAuthenticated: Bool = false
    @Published var currentUser: User? // Changed from Firebase User to Supabase User
    
    // Task handle for the auth state listener
    private var authStateTask: Task<Void, Never>? // Changed from Cancellable
    
    private override init() {
        super.init()
        // Start listening to auth state changes asynchronously
        authStateTask = Task {
            // Use for await to iterate through the stream
            for await (event, session) in supabase.auth.authStateChanges {
                print("Auth State Change: Event - \(event), Session Valid: \(session != nil)")
                // Update published properties (already on MainActor due to class annotation)
                self.isUserAuthenticated = session != nil
                self.currentUser = session?.user
                
                // Clear skip status if user signs in successfully
                if session != nil {
                    self.resetSkipStatus()
                }
            }
             print("Auth State Change listener task finished.") // Should not happen unless stream terminates
        }
    }
    
    deinit {
        // Cancel the listener task when service is deallocated
        authStateTask?.cancel()
        print("AuthenticationService deinit: Cancelled auth state task.")
    }
    
    // MARK: - Email Authentication
    
    func signInWithEmail(email: String, password: String) async throws {
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            print("Sign in successful for \(session.user.email ?? "unknown email")")
        } catch {
            print("Sign in error: \(error.localizedDescription)") // Corrected print
            throw AuthError.signInError(message: error.localizedDescription)
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        do {
            let session = try await supabase.auth.signUp(email: email, password: password)
             print("Sign up successful for \(session.user.email ?? "unknown email") - Confirmation may be required.")
        } catch {
             print("Sign up error: \(error.localizedDescription)") // Corrected print
            throw AuthError.signUpError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Apple Authentication
    
    func startSignInWithAppleFlow() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        return request
    }
    
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.appleSignInError(message: "Unable to retrieve Apple credentials")
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.appleSignInError(message: "Invalid state: A login callback was received, but no login request was sent.")
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.appleSignInError(message: "Unable to fetch identity token")
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.appleSignInError(message: "Unable to serialize token string from data")
        }
        
        do {
            // Corrected call using credentials parameter
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce)
            )
            print("Sign in with Apple successful for \(session.user.email ?? "unknown email")")
            
            // Handle user metadata (name) if desired and available
            // This might require an additional call to update user metadata in Supabase
            // if let fullName = appleIDCredential.fullName {
            //     let firstName = fullName.givenName ?? ""
            //     let lastName = fullName.familyName ?? ""
            //     let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
            //     if !displayName.isEmpty {
            //         // Example: Update Supabase user metadata (check supabase-swift docs for exact structure)
            //         // try await supabase.auth.updateUser(metadata: ["full_name": displayName])
            //         print("Need to implement Supabase user metadata update for name: \(displayName)")
            //     }
            // }
        } catch {
             print("Sign in with Apple error: \(error.localizedDescription)") // Corrected print
            throw AuthError.appleSignInError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws { // Make async as Supabase signOut is async
        do {
            try await supabase.auth.signOut()
             print("Sign out successful")
        } catch {
             print("Sign out error: \(error.localizedDescription)") // Corrected print
            throw AuthError.signOutError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Skip Authentication
    
    func skipAuthentication() {
        // Set as anonymous or guest user
        UserDefaults.standard.set(true, forKey: "didSkipAuthentication")
        
        // Ensure auth state reflects skip
        self.isUserAuthenticated = false
        self.currentUser = nil
        
        // We post a notification for UI updates, separate from auth state stream
        NotificationCenter.default.post(name: NSNotification.Name("DidSkipAuthentication"), object: nil)
        print("Authentication skipped") // Debug log
    }
    
    // Check if user previously skipped authentication
    func didUserSkipAuthentication() -> Bool {
        return UserDefaults.standard.bool(forKey: "didSkipAuthentication")
    }
    
    // Reset skip status (e.g., when user signs out or when you want to force authentication)
    func resetSkipStatus() {
        UserDefaults.standard.set(false, forKey: "didSkipAuthentication")
        print("Skip status reset") // Debug log
    }
    
    // MARK: - Password Reset
    
    func resetPassword(for email: String) async throws {
        do {
            // Check Supabase documentation for redirect URL requirements/options
            try await supabase.auth.resetPasswordForEmail(email) // Add redirect URL if needed: , redirectTo: URL(string: "your-app-url-scheme://reset-callback"))
            print("Password reset email sent to \(email)")
        } catch {
            print("Password reset error: \(error.localizedDescription)") // Corrected print
            throw AuthError.resetPasswordError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    // Generates a random nonce string for Apple sign in
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // Generates SHA256 hash of a string
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
} 
