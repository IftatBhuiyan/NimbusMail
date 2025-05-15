import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    var onCompletion: (Result<ASAuthorization, Error>) -> Void
    var buttonStyle: ASAuthorizationAppleIDButton.Style = .white
    var buttonType: ASAuthorizationAppleIDButton.ButtonType = .signIn
    var cornerRadius: CGFloat = 10
    
    var body: some View {
        SignInWithAppleButtonViewRepresentable(
            onCompletion: onCompletion,
            buttonStyle: buttonStyle,
            buttonType: buttonType
        )
        .frame(height: 50)
        .cornerRadius(cornerRadius)
    }
}

struct SignInWithAppleButtonViewRepresentable: UIViewRepresentable {
    var onCompletion: (Result<ASAuthorization, Error>) -> Void
    var buttonStyle: ASAuthorizationAppleIDButton.Style
    var buttonType: ASAuthorizationAppleIDButton.ButtonType
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
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
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
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