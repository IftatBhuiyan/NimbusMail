import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var showForgotPassword = false
    
    // Use neumorphic colors
    private let primaryColor = Color.blue // Keep for interactive elements
    private let neumorphicTextColor = Color(hex: "0D2750").opacity(0.8)
    
    var body: some View {
        NavigationView {
            ZStack {
                // Neumorphic Background
                neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) { // Reduced spacing from 30 to 20
                        // App Logo / Header (Neumorphic Style)
                        VStack(spacing: 10) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(primaryColor)
                                .padding(20)
                                .background(
                                    Circle()
                                        .fill(neumorphicBackgroundColor)
                                        .shadow(color: darkDropShadowColor, radius: 5, x: 5, y: 5)
                                        .shadow(color: lightDropShadowColor, radius: 5, x: -5, y: -5)
                                )
                            
                            Text("OneTracker")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(neumorphicTextColor)
                            
                            Text(isSignUp ? "Create your account" : "Sign in to continue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 30) // Reduced top padding from 40 to 30
                        
                        // Error Message (if any)
                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            ErrorMessageView(error: errorMessage)
                                .padding(.bottom, 5) // Add slight bottom padding
                        }
                        
                        // Form Fields (Neumorphic Text Fields)
                        VStack(spacing: -10) { // Further reduced spacing from 15 to 10
                            AuthTextField(
                                placeholder: "Email",
                                text: $email,
                                keyboardType: .emailAddress,
                                icon: "envelope.fill"
                            )
                            .modifier(NeumorphicInnerShadow()) // Keep inner shadow
                            
                            AuthTextField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: true,
                                icon: "lock.fill"
                            )
                            .modifier(NeumorphicInnerShadow()) // Keep inner shadow
                            
                            if isSignUp {
                                AuthTextField(
                                    placeholder: "Confirm Password",
                                    text: $confirmPassword,
                                    isSecure: true,
                                    icon: "lock.fill"
                                )
                                .modifier(NeumorphicInnerShadow()) // Keep inner shadow
                                .padding(.bottom, 5) // Add a small gap before Forgot Password when signing up
                            }
                            
                            // Forgot Password Link
                            if !isSignUp {
                                HStack {
                                    Spacer()
                                    Button("Forgot Password?") {
                                        showForgotPassword = true
                                    }
                                    .font(.footnote)
                                    .foregroundColor(primaryColor)
                                }
                                .padding(.top, 5)
                                .padding(.trailing, 15) // Add explicit right padding to match field's internal padding
                            }
                        }
                        
                        // Sign In/Sign Up Button (Neumorphic Style)
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
                            backgroundColor: primaryColor // Keep primary color
                        )
                        .neumorphicDropShadow()
                        .padding(.top, 15) // Add slight top padding
                        
                        // Separator
                        TextDivider(text: "OR")
                            .padding(.vertical, 10) // Add some vertical padding
                        
                        // Social Sign-in Options
                        VStack(spacing: 15) {
                            // Apple Sign In (Neumorphic)
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
                            .neumorphicDropShadow()
                            
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
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 10)
                            }
                            .padding(.top, 0) // Reduced top padding from 5 to 0
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
                            .foregroundColor(primaryColor)
                            .fontWeight(.bold)
                        }
                        .padding(.top, 15) // Adjusted top padding
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 30) // Reduced bottom padding
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(viewModel: viewModel)
                     .background(neumorphicBackgroundColor.edgesIgnoringSafeArea(.all)) // Background for sheet
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

// --- REMOVE Neumorphic View Modifiers Below --- 
// They should live in Utilities/NeumorphismStyles.swift

struct NeumorphicInnerShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(neumorphicBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(neumorphicBackgroundColor, lineWidth: 4) // Create inset effect
                            .shadow(color: darkInnerShadowColor, radius: darkInnerShadowBlur / 2, x: darkInnerShadowX / 2, y: darkInnerShadowY / 2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: lightInnerShadowColor, radius: lightInnerShadowBlur / 2, x: lightInnerShadowX / 2, y: lightInnerShadowY / 2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
            )
    }
}

struct NeumorphicDropShadow: ViewModifier {
     func body(content: Content) -> some View {
         content
             .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
             .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
     }
}

extension View {
    func neumorphicInnerShadow() -> some View {
        self.modifier(NeumorphicInnerShadow())
    }
    func neumorphicDropShadow() -> some View {
         self.modifier(NeumorphicDropShadow())
     }
} 