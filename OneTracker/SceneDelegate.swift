import UIKit
import SwiftUI
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        
        // Handle URL if provided in connection options
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingDynamicLink(urlContext.url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URLs when the app is already running
        if let urlContext = URLContexts.first {
            handleIncomingDynamicLink(urlContext.url)
        }
    }
    
    private func handleIncomingDynamicLink(_ incomingURL: URL) {
        // Handle Firebase Auth dynamic links (password reset, email verification, etc.)
        let link = incomingURL.absoluteString
        
        // Check if the link is a Firebase Auth sign-in link
        if Auth.auth().isSignIn(withEmailLink: link) {
            // Save the link for passwordless authentication
            UserDefaults.standard.set(link, forKey: "EmailSignInLink")
            
            // Post notification for auth components
            NotificationCenter.default.post(Notification(name: Notification.Name("EmailSignInLinkNotification")))
        }
    }
} 