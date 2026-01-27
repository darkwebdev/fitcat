//
//  ProductDetailView.swift
//  FitCat
//
//  Displays detailed product information with carbs meter
//

import SwiftUI

struct ProductDetailView: View {
    let product: Product

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var databaseManager: DatabaseManager

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Carbs Meter
                CarbsMeterView(
                    carbsPercentage: product.carbs,
                    carbsLevel: product.carbsLevel
                )
                .padding(.top)

                // Nutrient Comparison (below carbs meter)
                NutrientComparisonView(product: product)
                    .padding(.horizontal)

                // Product Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(product.productName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(product.brand)
                        .font(.title3)
                        .foregroundColor(.secondary)

                    if let barcode = product.barcode {
                        HStack {
                            Image(systemName: "barcode")
                                .foregroundColor(.secondary)
                            Text(barcode)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let servingSize = product.servingSize {
                        HStack {
                            Image(systemName: "scalemass")
                                .foregroundColor(.secondary)
                            Text(servingSize)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Divider()

                // Nutrition Grid
                VStack(spacing: 16) {
                    Text("Guaranteed Analysis")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        nutritionCard(label: "Protein", value: product.protein, color: .blue)
                        nutritionCard(label: "Fat", value: product.fat, color: .orange)
                        nutritionCard(label: "Fiber", value: product.fiber, color: .green)
                        nutritionCard(label: "Moisture", value: product.moisture, color: .cyan)
                        nutritionCard(label: "Ash", value: product.ash, color: .gray)
                        nutritionCard(label: "Carbs", value: product.carbs, color: product.carbsLevel.color)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Calories Breakdown
                VStack(spacing: 12) {
                    Text("Calories per 100g")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let calories = product.calories
                    HStack(spacing: 20) {
                        calorieInfo(label: "Protein", value: calories.proteinCal, color: .blue)
                        calorieInfo(label: "Fat", value: calories.fatCal, color: .orange)
                        calorieInfo(label: "Carbs", value: calories.carbsCal, color: product.carbsLevel.color)
                    }

                    Text("Total: \(product.totalCalories, specifier: "%.1f") kcal/100g")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)

                // Source indicator
                HStack {
                    Image(systemName: product.source == .local ? "person.fill" : "cloud.fill")
                        .font(.caption)
                    Text(product.source == .local ? "Manually Added" : "From Database")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Menu")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ProductFormView(product: product)
        }
        .alert("Delete Product", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteProduct()
            }
        } message: {
            Text("Are you sure you want to delete \(product.productName)?")
        }
    }

    private func nutritionCard(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(value, specifier: "%.1f")%")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    private func calorieInfo(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(value, specifier: "%.1f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)

            Text("kcal")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func deleteProduct() {
        do {
            try databaseManager.delete(product)
            dismiss()
        } catch {
            print("Failed to delete product: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        ProductDetailView(product: Product(
            barcode: "012345678901",
            productName: "Premium Cat Food",
            brand: "Fancy Feast",
            protein: 12.5,
            fat: 7.0,
            fiber: 1.5,
            moisture: 78.0,
            ash: 2.0,
            servingSize: "1 can (85g)",
            apiProtein: 11.5,
            apiFat: 6.5,
            apiFiber: 0.5,
            apiMoisture: 79.0,
            apiAsh: 1.8
        ))
    }
    .environmentObject(DatabaseManager.shared)
}
