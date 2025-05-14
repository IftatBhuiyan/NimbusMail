import UIKit
import SwiftUI
// import FirebaseAuth // Remove Firebase import
import Supabase // Add Supabase import

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        
        // Handle URL if provided in connection options
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URLs when the app is already running
        if let urlContext = URLContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }
    
    private func handleIncomingURL(_ incomingURL: URL) {
        // --- Remove Firebase Dynamic Link Handling --- 
        // let link = incomingURL.absoluteString
        // if Auth.auth().isSignIn(withEmailLink: link) {
        //     UserDefaults.standard.set(link, forKey: "EmailSignInLink")
        //     NotificationCenter.default.post(Notification(name: Notification.Name("EmailSignInLinkNotification"))) 
        // }
        
        // --- Add Supabase Deep Link Handling (Example) --- 
        // Check if the URL is intended for Supabase Auth
        Task { // Perform async check
            do {
                // Attempt to create a session from the URL (e.g., for email link auth, magic link)
                // This automatically handles the session update if the link is valid.
                let session = try await supabase.auth.session(from: incomingURL)
                print("Successfully handled Supabase auth deep link. Session user: \(session.user.email ?? "N/A")")
                // The auth state listener in AuthenticationService will automatically update the UI.
            } catch {
                // Check if it's a recoverable error or just not a Supabase link
                // You might want more specific error handling based on Supabase errors
                print("Incoming URL is not a valid Supabase session URL or an error occurred: \(error.localizedDescription)")
                // Handle other deep links if necessary
            }
        }
    }
} 