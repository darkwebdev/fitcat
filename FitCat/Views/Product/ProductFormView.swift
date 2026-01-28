//
//  ProductFormView.swift
//  FitCat
//
//  Form for adding/editing cat food products
//

import SwiftUI

struct ProductFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var databaseManager: DatabaseManager

    @State private var productName: String
    @State private var brand: String
    @State private var barcode: String
    @State private var protein: String
    @State private var fat: String
    @State private var fiber: String
    @State private var moisture: String
    @State private var ash: String
    @State private var servingSize: String

    @State private var showError = false
    @State private var errorMessage = ""

    let existingProduct: Product?
    let prefillData: NutritionInfo?
    let apiProduct: Product?

    init(
        product: Product? = nil,
        prefillData: NutritionInfo? = nil,
        apiProduct: Product? = nil
    ) {
        self.existingProduct = product
        self.prefillData = prefillData
        self.apiProduct = apiProduct

        // Helper to format double values
        func formatValue(_ value: Double?) -> String {
            guard let value = value else { return "" }
            return String(value)
        }

        // Initialize state from existing product or prefill data
        _productName = State(initialValue: product?.productName ?? "")
        _brand = State(initialValue: product?.brand ?? "")
        _barcode = State(initialValue: product?.barcode ?? "")
        _protein = State(initialValue: product?.protein.description ?? formatValue(prefillData?.protein))
        _fat = State(initialValue: product?.fat.description ?? formatValue(prefillData?.fat))
        _fiber = State(initialValue: product?.fiber.description ?? formatValue(prefillData?.fiber))
        _moisture = State(initialValue: product?.moisture.description ?? formatValue(prefillData?.moisture))
        _ash = State(initialValue: product?.ash.description ?? formatValue(prefillData?.ash))
        _servingSize = State(initialValue: product?.servingSize ?? "")
    }

    private var calculatedCarbs: Double {
        // Helper to parse numbers with comma or period as decimal separator
        func parseNumber(_ text: String) -> Double? {
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }

        guard let p = parseNumber(protein),
              let f = parseNumber(fat),
              let fi = parseNumber(fiber),
              let m = parseNumber(moisture),
              let a = parseNumber(ash) else {
            return 0
        }

        return NutritionCalculator.calculateCarbs(
            protein: p,
            fat: f,
            fiber: fi,
            moisture: m,
            ash: a
        )
    }

    private var carbsLevel: CarbsLevel {
        NutritionCalculator.getCarbsLevel(carbs: calculatedCarbs)
    }

    private var validationErrorMessage: String? {
        func parseNumber(_ text: String) -> Double? {
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }

        let p = parseNumber(protein) ?? 0
        let f = parseNumber(fat) ?? 0
        let fi = parseNumber(fiber) ?? 0
        let m = parseNumber(moisture) ?? 0
        let a = parseNumber(ash) ?? 0
        let total = p + f + fi + m + a

        if total > 102 {
            return "Total values exceed 102%. Please check your entries."
        }
        return nil
    }

    private var carbsSection: some View {
        Section("Calculated Carbohydrates") {
            HStack {
                Text("Carbs")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(calculatedCarbs, specifier: "%.2f")%")
                    .font(.headline)
                    .foregroundColor(carbsLevel.color)
                    .accessibilityIdentifier("Carbs Value")
            }

            HStack {
                Text("Status")
                    .foregroundColor(.secondary)
                Spacer()
                Text(carbsLevel.description)
                    .font(.headline)
                    .foregroundColor(carbsLevel.color)
                    .accessibilityIdentifier("Carbs Status")
            }

            if let errorMsg = validationErrorMessage {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Product Information") {
                    TextField("Product Name", text: $productName)
                        .accessibilityIdentifier("Product Name")
                    TextField("Brand", text: $brand)
                        .accessibilityIdentifier("Brand")
                    TextField("Barcode (optional)", text: $barcode)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("Barcode (optional)")
                    TextField("Serving Size (optional)", text: $servingSize)
                        .accessibilityIdentifier("Serving Size (optional)")
                }

                Section("Nutrition Values (%)") {
                    nutritionField(label: "Protein", value: $protein)
                    nutritionField(label: "Fat", value: $fat)
                    nutritionField(label: "Fiber", value: $fiber)
                    nutritionField(label: "Moisture", value: $moisture)
                    nutritionField(label: "Ash/Minerals", value: $ash)
                }

                carbsSection

                Section {
                    Text("Formula: carbs% = 100 × (100 - protein - fat - fiber - moisture - ash) / (100 - moisture)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(existingProduct == nil ? "Add Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProduct()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func nutritionField(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0.0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .accessibilityIdentifier(label + " Field")
            Text("%")
                .foregroundColor(.secondary)
        }
    }

    private var isValid: Bool {
        // Helper to parse numbers with comma or period as decimal separator
        func parseNumber(_ text: String) -> Double? {
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }

        guard !productName.trimmingCharacters(in: .whitespaces).isEmpty,
              !brand.trimmingCharacters(in: .whitespaces).isEmpty,
              let p = parseNumber(protein), p >= 0, p <= 100,
              let f = parseNumber(fat), f >= 0, f <= 100,
              let fi = parseNumber(fiber), fi >= 0, fi <= 100,
              let m = parseNumber(moisture), m >= 0, m < 100,
              let a = parseNumber(ash), a >= 0, a <= 100 else {
            return false
        }

        // Check total doesn't exceed 102% (allow small margin for rounding/testing variability)
        // Values should sum to ~100%, but allow 2% tolerance
        let total = p + f + fi + m + a
        return total <= 102
    }

    private func saveProduct() {
        // Helper to parse numbers with comma or period as decimal separator
        func parseNumber(_ text: String) -> Double? {
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }

        guard isValid,
              let p = parseNumber(protein),
              let f = parseNumber(fat),
              let fi = parseNumber(fiber),
              let m = parseNumber(moisture),
              let a = parseNumber(ash) else {
            return
        }

        let product = Product(
            id: existingProduct?.id ?? UUID(),
            barcode: barcode.isEmpty ? nil : barcode,
            productName: productName.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            protein: p,
            fat: f,
            fiber: fi,
            moisture: m,
            ash: a,
            servingSize: servingSize.isEmpty ? nil : servingSize,
            createdAt: existingProduct?.createdAt ?? Date(),
            updatedAt: Date(),
            source: apiProduct != nil ? .openpetfoodfacts : .local,
            categoriesTags: apiProduct?.categoriesTags,
            apiProtein: apiProduct?.protein,
            apiFat: apiProduct?.fat,
            apiFiber: apiProduct?.fiber,
            apiMoisture: apiProduct?.moisture,
            apiAsh: apiProduct?.ash
        )

        do {
            if existingProduct != nil {
                try databaseManager.update(product)
            } else {
                try databaseManager.insert(product)
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save product: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    ProductFormView()
        .environmentObject(DatabaseManager.shared)
}

#Preview("With Prefill") {
    ProductFormView(prefillData: NutritionInfo(
        protein: 40.0,
        fat: 18.0,
        fiber: 3.0,
        moisture: 10.0,
        ash: 8.0
    ))
    .environmentObject(DatabaseManager.shared)
}
