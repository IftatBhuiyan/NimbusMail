//
//  OneTrackerApp.swift
//  OneTracker
//
//  Created by Iftat Bhuiyan on 4/8/25.
//

import SwiftUI
import SwiftData // Re-add SwiftData import
import FirebaseCore
import GoogleSignIn // Import GoogleSignIn

// Configure Firebase & Google Sign-In
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Remove manual GIDSignIn configuration - SDK reads from Info.plist
        // guard let clientID = FirebaseApp.app()?.options.clientID else { return true }
        // GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        return true
    }
    
    // Handle the URL callback from Google Sign-In
    func application(_ app: UIApplication, 
                     open url: URL, 
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct OneTrackerApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Re-add the sharedModelContainer
    var sharedModelContainer: ModelContainer = {
        // Schema is now empty as Transaction is removed
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AuthWrapper()
                .modelContainer(sharedModelContainer)
                .withErrorHandling() // Add global error handling if needed
                .preferredColorScheme(.light) // Force light mode
        }
    }
}
