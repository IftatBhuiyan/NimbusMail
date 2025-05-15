//
//  NimbusApp.swift
//  Nimbus
//
//  Created by Iftat Bhuiyan on 4/8/25.
//

import SwiftUI
import SwiftData
import GoogleSignIn
import Supabase

// Helper function to read Info.plist values
func infoForKey(_ key: String) -> String? {
    return (Bundle.main.infoDictionary?[key] as? String)
}

// Global Supabase client instance
let supabase: SupabaseClient = {
    guard let urlString = infoForKey("SupabaseURL"), let url = URL(string: urlString) else {
        fatalError("SupabaseURL not found or invalid in Info.plist")
    }
    guard let key = infoForKey("SupabaseAnonKey") else {
        fatalError("SupabaseAnonKey not found in Info.plist")
    }
    
    return SupabaseClient(supabaseURL: url, supabaseKey: key)
}()

// Configure Google Sign-In (if still needed for adding accounts)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Google Sign-In configuration remains if needed for adding accounts
        
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
struct NimbusApp: App {
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
