//
//  SettingsView.swift
//  FitCat
//
//  App settings including GitHub sync
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var cacheSize: String = "Calculating..."

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

                #if DEBUG
                Section("Debug") {
                    HStack {
                        Text("Cached Products")
                        Spacer()
                        Text("\(databaseManager.products.count)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("By Source")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("API: \(databaseManager.products.filter { $0.source == .openpetfoodfacts }.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Local: \(databaseManager.products.filter { $0.source == .local }.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("GitHub: \(databaseManager.products.filter { $0.source == .github }.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .monospacedDigit()
                    }

                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Cache")
                        }
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .onAppear {
                calculateCacheSize()
            }
        }
    }

    private func calculateCacheSize() {
        Task {
            do {
                let fileManager = FileManager.default
                let documentsPath = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let dbPath = documentsPath.appendingPathComponent("fitcat.sqlite3")

                if let attrs = try? fileManager.attributesOfItem(atPath: dbPath.path),
                   let fileSize = attrs[.size] as? UInt64 {
                    await MainActor.run {
                        self.cacheSize = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
                    }
                } else {
                    await MainActor.run {
                        self.cacheSize = "0 KB"
                    }
                }
            } catch {
                await MainActor.run {
                    self.cacheSize = "Unknown"
                }
            }
        }
    }

    private func clearCache() {
        for product in databaseManager.products {
            try? databaseManager.delete(product)
        }
        try? databaseManager.loadProducts()
        calculateCacheSize()
    }
}

#Preview {
    SettingsView()
}
