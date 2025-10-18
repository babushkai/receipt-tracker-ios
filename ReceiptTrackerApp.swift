//
//  ReceiptTrackerApp.swift
//  ReceiptTracker
//
//  Main app entry point
//

import SwiftUI

@main
struct ReceiptTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
        }
    }
}

// App-wide state management
class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var isProcessingReceipt: Bool = false
}

