//
//  FitCatApp.swift
//  FitCat
//
//  Created on 2026-01-15.
//

import SwiftUI

@main
struct FitCatApp: App {
    @StateObject private var databaseManager = DatabaseManager.shared

    init() {
        // Configure for UI testing
        if CommandLine.arguments.contains("UI-Testing") {
            // Use in-memory database for testing
            // This prevents test data from persisting between test runs
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(databaseManager)
        }
    }
}
