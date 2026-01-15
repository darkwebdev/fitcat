//
//  HomeView.swift
//  FitCat
//
//  Home screen with product list and search
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var databaseManager: DatabaseManager
    @State private var searchText = ""
    @State private var showAddSheet = false

    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return databaseManager.products
        } else {
            return databaseManager.products.filter { product in
                product.productName.localizedCaseInsensitiveContains(searchText) ||
                product.brand.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if databaseManager.products.isEmpty {
                    emptyState
                } else {
                    productList
                }
            }
            .navigationTitle("FitCat")
            .searchable(text: $searchText, prompt: "Search products")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ProductFormView()
            }
        }
    }

    private var productList: some View {
        List {
            ForEach(filteredProducts) { product in
                NavigationLink(destination: ProductDetailView(product: product)) {
                    ProductRowView(product: product)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Products Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityIdentifier("No Products Yet")

            Text("Add your first cat food product to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Add your first cat food product to get started")

            Button {
                showAddSheet = true
            } label: {
                Label("Add Product", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityIdentifier("Add Product")
            .padding(.top)
        }
        .padding()
    }
}

struct ProductRowView: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            // Carbs indicator
            ZStack {
                Circle()
                    .fill(product.carbsLevel.color.opacity(0.2))
                    .frame(width: 50, height: 50)

                Text("\(product.carbs, specifier: "%.1f")")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(product.carbsLevel.color)
                    .accessibilityIdentifier("Carbs Indicator")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.headline)
                    .lineLimit(1)

                Text(product.brand)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    nutritionBadge(label: "P", value: product.protein)
                    nutritionBadge(label: "F", value: product.fat)
                    nutritionBadge(label: "M", value: product.moisture)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func nutritionBadge(label: String, value: Double) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value, specifier: "%.0f")")
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(DatabaseManager.shared)
}
