//
//  MainView.swift
//  FitCat
//
//  Root navigation view with tabs
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Products", systemImage: "list.bullet")
                }

            ScannerView()
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(DatabaseManager.shared)
}
