import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    var onCompletion: (Result<ASAuthorization, Error>) -> Void
    var buttonType: ASAuthorizationAppleIDButton.ButtonType = .signIn
    var cornerRadius: CGFloat = 10
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SignInWithAppleButtonViewRepresentable(
            onCompletion: onCompletion,
            buttonStyle: colorScheme == .dark ? .white : .black,
            buttonType: buttonType,
            colorScheme: colorScheme
        )
        .frame(height: 50)
        .cornerRadius(cornerRadius)
        .id("AppleSignInButton-\(colorScheme == .dark ? "dark" : "light")")
    }
}

struct SignInWithAppleButtonViewRepresentable: UIViewRepresentable {
    var onCompletion: (Result<ASAuthorization, Error>) -> Void
    var buttonStyle: ASAuthorizationAppleIDButton.Style
    var buttonType: ASAuthorizationAppleIDButton.ButtonType
    var colorScheme: ColorScheme
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        print("Creating Apple button with style: \(buttonStyle == .white ? "white" : "black") for scheme: \(colorScheme == .dark ? "dark" : "light")")
        
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: buttonType,
            authorizationButtonStyle: buttonStyle
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didTapButton),
            for: .touchUpInside
        )
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // We can't modify the style after creation
        // This is handled by recreating the button with the .id() modifier
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButtonViewRepresentable
        
        init(_ parent: SignInWithAppleButtonViewRepresentable) {
            self.parent = parent
        }
        
        @objc func didTapButton() {
            let authService = AuthenticationService.shared
            let request = authService.startSignInWithAppleFlow()
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
        
        // ASAuthorizationControllerDelegate
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }
        
        // ASAuthorizationControllerPresentationContextProviding
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first ?? UIWindow()
            return window
        }
    }
} 