//
//  NutrientComparisonView.swift
//  FitCat
//
//  Shows API vs Scanned nutrient values with green highlighting for final values
//

import SwiftUI

struct NutrientComparisonView: View {
    let product: Product

    private var hasApiValues: Bool {
        product.apiProtein != nil ||
        product.apiFat != nil ||
        product.apiFiber != nil ||
        product.apiMoisture != nil ||
        product.apiAsh != nil
    }

    var body: some View {
        if hasApiValues {
            VStack(spacing: 12) {
                Text("Nutrient Comparison")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("Nutrient")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("From API")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)

                        Text("")
                            .frame(width: 30)

                        Text("Scanned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))

                    // Nutrient rows
                    comparisonRow(
                        label: "Protein",
                        apiValue: product.apiProtein,
                        scannedValue: product.protein,
                        color: .blue
                    )

                    Divider()

                    comparisonRow(
                        label: "Fat",
                        apiValue: product.apiFat,
                        scannedValue: product.fat,
                        color: .orange
                    )

                    Divider()

                    comparisonRow(
                        label: "Fiber",
                        apiValue: product.apiFiber,
                        scannedValue: product.fiber,
                        color: .green
                    )

                    Divider()

                    comparisonRow(
                        label: "Moisture",
                        apiValue: product.apiMoisture,
                        scannedValue: product.moisture,
                        color: .cyan
                    )

                    Divider()

                    comparisonRow(
                        label: "Ash",
                        apiValue: product.apiAsh,
                        scannedValue: product.ash,
                        color: .gray
                    )
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    private func comparisonRow(
        label: String,
        apiValue: Double?,
        scannedValue: Double,
        color: Color
    ) -> some View {
        let hasChange = apiValue != nil && abs(apiValue! - scannedValue) > 0.1
        let isFinal = hasChange

        return HStack(spacing: 0) {
            // Nutrient label
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // API value
            if let api = apiValue {
                Text(String(format: "%.1f%%", api))
                    .font(.subheadline)
                    .foregroundColor(hasChange ? .secondary : .green)
                    .fontWeight(hasChange ? .regular : .semibold)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }

            // Arrow (if changed)
            Group {
                if hasChange {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                } else {
                    Text("")
                }
            }
            .frame(width: 30)

            // Scanned value (final)
            Text(String(format: "%.1f%%", scannedValue))
                .font(.subheadline)
                .foregroundColor(isFinal ? .green : .primary)
                .fontWeight(isFinal ? .semibold : .regular)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Product with API values that differ from scanned
        NutrientComparisonView(product: Product(
            productName: "Test Food",
            brand: "Test Brand",
            protein: 12.5,
            fat: 7.0,
            fiber: 1.5,
            moisture: 78.0,
            ash: 2.0,
            apiProtein: 11.5,
            apiFat: 6.5,
            apiFiber: 0.5,
            apiMoisture: 79.0,
            apiAsh: 1.8
        ))

        // Product with no API values (won't show)
        NutrientComparisonView(product: Product(
            productName: "Test Food 2",
            brand: "Test Brand",
            protein: 12.5,
            fat: 7.0,
            fiber: 1.5,
            moisture: 78.0,
            ash: 2.0
        ))
    }
    .padding()
}
