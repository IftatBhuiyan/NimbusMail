import Foundation
import Combine
import FirebaseAuth
import AuthenticationServices

@MainActor
class UserViewModel: ObservableObject {
    // Published properties
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Auth service
    private let authService = AuthenticationService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Subscribe to authentication state changes
        authService.$isUserAuthenticated
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        // Subscribe to current user changes
        authService.$currentUser
            .sink { [weak self] user in
                self?.userEmail = user?.email
                self?.userName = user?.displayName
            }
            .store(in: &cancellables)
        
        // Check current auth state
        isAuthenticated = Auth.auth().currentUser != nil
        userEmail = Auth.auth().currentUser?.email
        userName = Auth.auth().currentUser?.displayName
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signInWithEmail(email: email, password: password)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUpWithEmail(email: email, password: password)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    func signOut() {
        errorMessage = nil
        
        do {
            try authService.signOut()
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(for: email)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    // MARK: - Apple Authentication
    
    func signInWithApple(authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signInWithApple(authorization: authorization)
            isLoading = false
        } catch let error as AuthError {
            handleError(error)
        } catch {
            handleError(AuthError.unknown(message: error.localizedDescription))
        }
    }
    
    // MARK: - Skip Authentication
    
    func handleSkipAuthentication() async {
        // Reset any errors and loading state
        errorMessage = nil
        isLoading = false
        
        // Set the authentication state to allow access
        self.isAuthenticated = true
        
        // You can set default user information for guest users if needed
        self.userEmail = "guest@example.com"
        self.userName = "Guest User"
    }
    
    // Handle all authentication errors
    private func handleError(_ error: AuthError) {
        isLoading = false
        
        switch error {
        case .signInError(let message),
             .signUpError(let message),
             .signOutError(let message),
             .unknown(let message):
            errorMessage = message
        case .userNotFound:
            errorMessage = "User not found. Please check your email or sign up."
        case .invalidCredentials:
            errorMessage = "Invalid email or password. Please try again."
        }
    }
} 