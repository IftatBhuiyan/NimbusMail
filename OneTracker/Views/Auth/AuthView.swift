import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    
    // Use adaptive colors
    @Environment(\.colorScheme) var colorScheme // Detect color scheme
    
    private var neumorphicTextColor: Color {
        // Example: Use primary for text, adapt if needed
        .primary 
    }
    private var primaryButtonColor: Color {
        .accentColor // Use the app's accent color
    }
    private var secondaryTextColor: Color {
        .secondary
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Adaptive Background (Using system background)
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) { 
                        // App Logo / Header
                        VStack(spacing: 10) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.accentColor) // Use accent color
                                .padding(20)
                                .background(
                                    Circle()
                                        .fill(Color(UIColor.systemBackground)) // Adaptive fill
                                        // Replace neumorphic shadows with simpler adaptive shadow
                                        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
                                )
                            
                            Text("OneTracker")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary) // Use primary text color
                            
                            Text(isSignUp ? "Create your account" : "Sign in to continue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 30)
                        
                        // Error Message (Uses adaptive colors already)
                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            ErrorMessageView(error: errorMessage)
                                .padding(.bottom, 5)
                        }
                        
                        // Form Fields (Will use adaptive styles from AuthUIComponents)
                        VStack(spacing: 10) { 
                            AuthTextField(
                                placeholder: "Email",
                                text: $email,
                                keyboardType: .emailAddress,
                                icon: "envelope.fill"
                            )
                            // Removed NeumorphicInnerShadow modifier
                            
                            AuthTextField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: true,
                                icon: "lock.fill"
                            )
                            // Removed NeumorphicInnerShadow modifier
                            
                            if isSignUp {
                                AuthTextField(
                                    placeholder: "Confirm Password",
                                    text: $confirmPassword,
                                    isSecure: true,
                                    icon: "lock.fill"
                                )
                                // Removed NeumorphicInnerShadow modifier
                                .padding(.bottom, 5)
                            }
                            
                            // Forgot Password Link
                            if !isSignUp {
                                HStack {
                                    Spacer()
                                    Button("Forgot Password?") {
                                        showForgotPassword = true
                                    }
                                    .font(.footnote)
                                    .foregroundColor(.accentColor) // Use accent color
                                }
                                .padding(.top, 5)
                            }
                        }
                        
                        // Sign In/Sign Up Button (Will use adaptive styles from AuthUIComponents)
                        PrimaryButton(
                            title: isSignUp ? "Create Account" : "Sign In",
                            action: {
                                if isSignUp {
                                    Task {
                                        if isValidSignUp() {
                                            await viewModel.signUp(email: email, password: password)
                                        }
                                    }
                                } else {
                                    Task {
                                        await viewModel.signIn(email: email, password: password)
                                    }
                                }
                            },
                            isLoading: viewModel.isLoading,
                            backgroundColor: .accentColor // Use accent color
                        )
                        // Removed neumorphicDropShadow modifier
                        .padding(.top, 15)
                        
                        // Separator (Uses adaptive colors already)
                        TextDivider(text: "OR")
                            .padding(.vertical, 10)
                        
                        // Social Sign-in Options
                        VStack(spacing: 15) {
                            // Apple Sign In (Uses system style which is adaptive)
                            AppleSignInButton { result in
                                switch result {
                                case .success(let authorization):
                                    Task {
                                        await viewModel.signInWithApple(authorization: authorization)
                                    }
                                case .failure(let error):
                                    viewModel.errorMessage = error.localizedDescription
                                }
                            }
                            .frame(height: 50)
                            // Removed neumorphicDropShadow modifier
                            
                            // Skip Authentication Button
                            Button(action: {
                                AuthenticationService.shared.skipAuthentication()
                                // Notify view model about skipping authentication
                                Task {
                                    await viewModel.handleSkipAuthentication()
                                }
                            }) {
                                Text("Skip Sign In")
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary) // Use secondary text color
                                    .padding(.vertical, 10)
                            }
                            .padding(.top, 0)
                        }
                        
                        // Toggle between Sign In and Sign Up
                        HStack {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundColor(.secondary)
                            
                            Button(isSignUp ? "Sign In" : "Sign Up") {
                                withAnimation {
                                    isSignUp.toggle()
                                    clearFields()
                                }
                            }
                            .foregroundColor(.accentColor) // Use accent color
                            .fontWeight(.bold)
                        }
                        .padding(.top, 15)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(viewModel: viewModel)
                     .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)) // Adaptive background
            }
        }
    }
    
    // Validation for sign up form
    private func isValidSignUp() -> Bool {
        guard !email.isEmpty else {
            viewModel.errorMessage = "Email cannot be empty"
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            viewModel.errorMessage = "Please enter a valid email address"
            return false
        }
        
        guard !password.isEmpty else {
            viewModel.errorMessage = "Password cannot be empty"
            return false
        }
        
        guard password.count >= 6 else {
            viewModel.errorMessage = "Password must be at least 6 characters"
            return false
        }
        
        guard password == confirmPassword else {
            viewModel.errorMessage = "Passwords do not match"
            return false
        }
        
        return true
    }
    
    // Clear form fields
    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
        viewModel.errorMessage = nil
    }
}

// Forgot Password Sheet
struct ForgotPasswordView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var email = ""
    @State private var emailSent = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Header
                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Error Message (if any)
                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    ErrorMessageView(error: errorMessage)
                }
                
                // Success Message
                if emailSent {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Password reset email sent!")
                            .font(.footnote)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Email Field
                AuthTextField(
                    placeholder: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    icon: "envelope"
                )
                
                // Reset Button
                PrimaryButton(
                    title: "Send Reset Link",
                    action: {
                        Task {
                            await resetPassword()
                        }
                    },
                    isLoading: viewModel.isLoading,
                    backgroundColor: .blue
                )
                
                Spacer()
            }
            .padding(.horizontal, 25)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    // Reset password logic
    private func resetPassword() async {
        guard !email.isEmpty else {
            viewModel.errorMessage = "Please enter your email address"
            return
        }
        
        await viewModel.resetPassword(email: email)
        if viewModel.errorMessage == nil {
            emailSent = true
        }
    }
}

// --- REMOVE ALL Neumorphic Modifiers and Extensions Below ---
// (These should not be here) 