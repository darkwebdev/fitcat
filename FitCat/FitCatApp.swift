//
//  FitCatApp.swift
//  FitCat
//
//  Created on 2026-01-15.
//

import SwiftUI

@main
struct FitCatApp: App {
    init() {
        print("FITCAT: App initialized - \(Date())")
        NSLog("FITCAT: App initialized")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    print("FITCAT: MainView appeared")
                    NSLog("FITCAT: MainView appeared")
                }
        }
    }
}
