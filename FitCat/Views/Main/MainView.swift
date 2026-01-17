//
//  MainView.swift
//  FitCat
//
//  Root navigation view with tabs
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    @State private var scannerResetTrigger = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerView(resetTrigger: $scannerResetTrigger)
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 0 {
                // Increment trigger to reset scanner when tab is selected
                scannerResetTrigger += 1
            }
        }
    }
}

#Preview {
    MainView()
}
