//
//  OneTrackerApp.swift
//  OneTracker
//
//  Created by Iftat Bhuiyan on 4/8/25.
//

import SwiftUI
import SwiftData // Re-add SwiftData import

@main
struct OneTrackerApp: App {
    // Re-add the sharedModelContainer
    var sharedModelContainer: ModelContainer = {
        // Include Transaction in the schema
        let schema = Schema([
            Transaction.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Re-add the modelContainer modifier
        .modelContainer(sharedModelContainer)
    }
}
