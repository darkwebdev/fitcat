//
//  SettingsView.swift
//  FitCat
//
//  App settings including GitHub sync
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @StateObject private var syncService: GitHubSyncService

    @State private var showingSyncError = false
    @State private var githubURL = "https://raw.githubusercontent.com/YOUR_USERNAME/fitcat-database/main/products.json"

    init() {
        let dbManager = DatabaseManager.shared
        _syncService = StateObject(wrappedValue: GitHubSyncService(databaseManager: dbManager))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Database Sync") {
                    if let lastSync = syncService.lastSyncDate {
                        HStack {
                            Text("Last Synced")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Never synced")
                            .foregroundColor(.secondary)
                    }

                    if syncService.isSyncing {
                        HStack {
                            ProgressView()
                            Text("Syncing...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            Task {
                                await syncService.forceSync()
                                if syncService.syncError != nil {
                                    showingSyncError = true
                                }
                            }
                        } label: {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                        }
                    }

                    TextField("GitHub Database URL", text: $githubURL)
                        .font(.caption)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Products in Database")
                        Spacer()
                        Text("\(databaseManager.products.count)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("About") {
                    Text("FitCat helps you calculate carbohydrate percentages in cat food to ensure your cat gets optimal nutrition.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Carbs should be ≤10% for healthy cats, with ≤5% being ideal.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Sync Error", isPresented: $showingSyncError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = syncService.syncError {
                    Text(error.localizedDescription)
                }
            }
            .onAppear {
                // Auto-sync if needed
                if syncService.shouldSync() {
                    Task {
                        await syncService.sync()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(DatabaseManager.shared)
}
