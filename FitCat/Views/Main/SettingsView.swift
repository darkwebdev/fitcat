//
//  SettingsView.swift
//  FitCat
//
//  App settings including GitHub sync
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section("Data Source") {
                    HStack {
                        Image(systemName: "cloud")
                        Text("Open Pet Food Facts")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    Text("All product data is fetched directly from Open Pet Food Facts API. New products you scan are automatically contributed to the community database.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
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
        }
    }
}

#Preview {
    SettingsView()
}
