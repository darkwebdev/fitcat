//
//  ProductComparisonView.swift
//  FitCat
//
//  Shows comparison between database values and scanned OCR values
//

import SwiftUI
import Foundation

struct ProductComparisonView: View {
    let databaseProduct: Product
    let ocrNutrition: NutritionInfo

    @Environment(\.dismiss) private var dismiss
    @State private var isUploading = false
    @State private var showUploadSuccess = false
    @State private var uploadError: String?
    @State private var showError = false

    private var hasChanges: Bool {
        if let ocrProtein = ocrNutrition.protein, abs(ocrProtein - databaseProduct.protein) > 0.1 { return true }
        if let ocrFat = ocrNutrition.fat, abs(ocrFat - databaseProduct.fat) > 0.1 { return true }
        if let ocrFiber = ocrNutrition.fiber, abs(ocrFiber - databaseProduct.fiber) > 0.1 { return true }
        if let ocrMoisture = ocrNutrition.moisture, abs(ocrMoisture - databaseProduct.moisture) > 0.1 { return true }
        if let ocrAsh = ocrNutrition.ash, abs(ocrAsh - databaseProduct.ash) > 0.1 { return true }
        return false
    }

    private var updatedProduct: Product {
        var product = databaseProduct

        // Update with OCR values where they differ
        if let ocrProtein = ocrNutrition.protein, abs(ocrProtein - product.protein) > 0.1 {
            product.protein = ocrProtein
        }
        if let ocrFat = ocrNutrition.fat, abs(ocrFat - product.fat) > 0.1 {
            product.fat = ocrFat
        }
        if let ocrFiber = ocrNutrition.fiber, abs(ocrFiber - product.fiber) > 0.1 {
            product.fiber = ocrFiber
        }
        if let ocrMoisture = ocrNutrition.moisture, abs(ocrMoisture - product.moisture) > 0.1 {
            product.moisture = ocrMoisture
        }
        if let ocrAsh = ocrNutrition.ash, abs(ocrAsh - product.ash) > 0.1 {
            product.ash = ocrAsh
        }

        return product
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Product Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(databaseProduct.productName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(databaseProduct.brand)
                            .font(.title3)
                            .foregroundColor(.secondary)

                        if let barcode = databaseProduct.barcode {
                            HStack {
                                Image(systemName: "barcode")
                                    .foregroundColor(.secondary)
                                Text(barcode)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)

                    if hasChanges {
                        // Info banner
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Scanned values differ from database")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Review the changes and update the database if correct")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        // No changes banner
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Scanned values match database")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Divider()

                    // Comparison Grid
                    VStack(spacing: 16) {
                        HStack {
                            Text("Nutrition Comparison")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 16) {
                                Label("Database", systemImage: "cloud")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Label("Scanned", systemImage: "camera")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal)

                        comparisonRow(
                            label: "Protein",
                            dbValue: databaseProduct.protein,
                            ocrValue: ocrNutrition.protein,
                            color: .blue
                        )

                        comparisonRow(
                            label: "Fat",
                            dbValue: databaseProduct.fat,
                            ocrValue: ocrNutrition.fat,
                            color: .orange
                        )

                        comparisonRow(
                            label: "Fiber",
                            dbValue: databaseProduct.fiber,
                            ocrValue: ocrNutrition.fiber,
                            color: .green
                        )

                        comparisonRow(
                            label: "Moisture",
                            dbValue: databaseProduct.moisture,
                            ocrValue: ocrNutrition.moisture,
                            color: .cyan
                        )

                        comparisonRow(
                            label: "Ash",
                            dbValue: databaseProduct.ash,
                            ocrValue: ocrNutrition.ash,
                            color: .gray
                        )
                    }

                    if hasChanges {
                        // Update button
                        Button {
                            uploadUpdatedProduct()
                        } label: {
                            HStack {
                                if isUploading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isUploading ? "Updating Database..." : "Update Database with Scanned Values")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isUploading ? Color.gray : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(isUploading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // View full details button
                    Button {
                        // TODO: Navigate to ProductDetailView
                    } label: {
                        Text("View Full Product Details")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Product Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Success!", isPresented: $showUploadSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Database updated successfully. Thank you for contributing!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(uploadError ?? "Unknown error")
            }
        }
    }

    private func comparisonRow(label: String, dbValue: Double, ocrValue: Double?, color: Color) -> some View {
        let hasChange = ocrValue != nil && abs((ocrValue ?? 0) - dbValue) > 0.1

        return VStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // Database value
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "cloud")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(dbValue, specifier: "%.1f")%")
                            .font(.body)
                            .fontWeight(hasChange ? .regular : .semibold)
                            .foregroundColor(hasChange ? .secondary : color)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hasChange ? Color.gray.opacity(0.1) : color.opacity(0.1))
                )

                // Arrow if changed
                if hasChange {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }

                // Scanned value
                if let ocrValue = ocrValue {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("\(ocrValue, specifier: "%.1f")%")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(hasChange ? .green : color)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(hasChange ? Color.green.opacity(0.15) : color.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(hasChange ? Color.green : Color.clear, lineWidth: 2)
                            )
                    )
                } else {
                    // No scanned value
                    Text("—")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.05))
                        )
                }
            }
        }
        .padding(.horizontal)
    }

    private func uploadUpdatedProduct() {
        guard hasChanges else { return }

        Task {
            isUploading = true

            do {
                let service = OpenPetFoodFactsService()
                let success = try await service.uploadProduct(updatedProduct)

                await MainActor.run {
                    isUploading = false

                    if success {
                        showUploadSuccess = true
                    } else {
                        uploadError = "Upload failed. Please try again."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadError = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ProductComparisonView(
        databaseProduct: Product(
            barcode: "4017721837194",
            productName: "Catessy Chunks in Jelly",
            brand: "Catessy",
            protein: 8.0,
            fat: 5.0,
            fiber: 0.3,
            moisture: 82.0,
            ash: 1.5,
            servingSize: nil
        ),
        ocrNutrition: NutritionInfo(
            protein: 10.5,
            fat: 6.5,
            fiber: 0.5,
            moisture: 79.0,
            ash: 2.1
        )
    )
}
