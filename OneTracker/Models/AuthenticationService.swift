import Foundation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit

// Authentication error types
enum AuthError: Error {
    case signInError(message: String)
    case signUpError(message: String)
    case signOutError(message: String)
    case userNotFound
    case invalidCredentials
    case unknown(message: String)
}

// Authentication service class to handle all Firebase authentication
class AuthenticationService: NSObject {
    static let shared = AuthenticationService()
    
    // Current nonce for Apple sign-in
    private var currentNonce: String?
    
    // Authentication state
    @Published var isUserAuthenticated: Bool = false
    @Published var currentUser: User?
    
    // Store the auth state listener handle
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private override init() {
        super.init()
        // Listen for auth state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isUserAuthenticated = user != nil
            self?.currentUser = user
        }
    }
    
    deinit {
        // Remove listener when service is deallocated
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Email Authentication
    
    func signInWithEmail(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.currentUser = result.user
            self.isUserAuthenticated = true
        } catch {
            throw AuthError.signInError(message: error.localizedDescription)
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.currentUser = result.user
            self.isUserAuthenticated = true
        } catch {
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
            throw AuthError.signInError(message: "Unable to retrieve Apple credentials")
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.signInError(message: "Invalid state: A login callback was received, but no login request was sent.")
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.signInError(message: "Unable to fetch identity token")
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.signInError(message: "Unable to serialize token string from data")
        }
        
        // Create Apple credential using the updated API
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        do {
            // Sign in with Firebase
            let result = try await Auth.auth().signIn(with: credential)
            self.currentUser = result.user
            self.isUserAuthenticated = true
            
            // Update user profile with name if available (usually only on first sign-in)
            if let fullName = appleIDCredential.fullName, let user = Auth.auth().currentUser {
                let displayName = "\(fullName.givenName ?? "") \(fullName.familyName ?? "")"
                if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                }
            }
        } catch {
            throw AuthError.signInError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isUserAuthenticated = false
        } catch {
            throw AuthError.signOutError(message: error.localizedDescription)
        }
    }
    
    // MARK: - Skip Authentication
    
    func skipAuthentication() {
        // Set as anonymous or guest user
        UserDefaults.standard.set(true, forKey: "didSkipAuthentication")
        
        // We'll keep isUserAuthenticated as false since they're not actually authenticated
        // but the app can check this flag to allow access
        self.isUserAuthenticated = false
        self.currentUser = nil
        
        // You can post a notification to inform the UI that the user has skipped auth
        NotificationCenter.default.post(name: NSNotification.Name("DidSkipAuthentication"), object: nil)
    }
    
    // Check if user previously skipped authentication
    func didUserSkipAuthentication() -> Bool {
        return UserDefaults.standard.bool(forKey: "didSkipAuthentication")
    }
    
    // Reset skip status (e.g., when user signs out or when you want to force authentication)
    func resetSkipStatus() {
        UserDefaults.standard.set(false, forKey: "didSkipAuthentication")
    }
    
    // MARK: - Password Reset
    
    func resetPassword(for email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError.unknown(message: error.localizedDescription)
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
