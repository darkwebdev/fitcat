//
//  OCRScannerView.swift
//  FitCat
//
//  OCR scanner for nutrition labels with inline comparison
//

import SwiftUI
import AVFoundation
import UIKit
import Vision

struct IconHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct OCRScannerView: View {
    let onNutritionScanned: (NutritionInfo) -> Void
    @Binding var resetTrigger: Int

    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var detectedNutrition: NutritionInfo?
    @State private var detectedBarcode: String?
    @StateObject private var cameraModel = CameraModel()
    @State private var scanTimer: Timer?
    @State private var scanStartTime: Date?
    @State private var apiStartTime: Date?

    // Product fields
    @State private var productName = ""
    @State private var brand = ""
    @State private var isLoadingProduct = false
    @State private var productNotFound = false
    @State private var showNutritionValues = false

    // Database product (from API)
    @State private var apiProduct: Product?

    // OCR nutrition values
    @State private var ocrProtein: Double?
    @State private var ocrFat: Double?
    @State private var ocrFiber: Double?
    @State private var ocrMoisture: Double?
    @State private var ocrAsh: Double?

    // Upload state
    @State private var isUploading = false
    @State private var showUploadSuccess = false
    @State private var uploadError: String?
    @State private var showError = false

    // Photo picker
    @State private var showingPhotoPicker = false
    @State private var showingMultiplePhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedImages: [UIImage]?
    @State private var imageProcessingIndex = 0
    @State private var imageProcessingTimer: Timer?

    // Scroll control
    @State private var scrollProxy: ScrollViewProxy?

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private var hasNutritionValues: Bool {
        return apiProduct != nil || ocrProtein != nil || ocrFat != nil || ocrFiber != nil || ocrMoisture != nil || ocrAsh != nil
    }

    private var shouldShowUpdateButton: Bool {
        guard let api = apiProduct else { return false }

        if let ocr = ocrProtein, let apiProtein = api.protein, abs(ocr - apiProtein) > 0.1 { return true }
        if let ocr = ocrFat, let apiFat = api.fat, abs(ocr - apiFat) > 0.1 { return true }
        if let ocr = ocrFiber, let apiFiber = api.fiber, abs(ocr - apiFiber) > 0.1 { return true }
        if let ocr = ocrMoisture, let apiMoisture = api.moisture, abs(ocr - apiMoisture) > 0.1 { return true }
        if let ocr = ocrAsh, let apiAsh = api.ash, abs(ocr - apiAsh) > 0.1 { return true }

        return false
    }

    private var validationErrors: [NutritionValidation.ValidationError] {
        // Only validate when we have all required values
        guard ocrProtein != nil && ocrFat != nil && ocrFiber != nil && ocrMoisture != nil && ocrAsh != nil else {
            return []
        }

        return NutritionValidation.validate(
            protein: ocrProtein,
            fat: ocrFat,
            fiber: ocrFiber,
            moisture: ocrMoisture,
            ash: ocrAsh
        )
    }

    init(resetTrigger: Binding<Int>, onNutritionScanned: @escaping (NutritionInfo) -> Void = { _ in }) {
        self._resetTrigger = resetTrigger
        self.onNutritionScanned = onNutritionScanned
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera background (fixed, does not scroll)
                if isSimulator {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))

                            Text("Running in Simulator")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Tap to select photos")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .offset(y: -geometry.size.height / 6)

                        FoodCanOverlay()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        showingMultiplePhotoPicker = true
                    }
                } else {
                    ZStack {
                        CameraPreview(camera: cameraModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        FoodCanOverlay()
                    }
                }

                // Scrollable content overlay
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Transparent spacer to push content to bottom initially
                            Color.clear
                                .frame(height: geometry.size.height)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showingMultiplePhotoPicker = true
                                }
                                .id("camera")

                            // Product form
                    VStack(spacing: 0) {
                        if productNotFound {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Product not found in database. Please enter details manually.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }

                        // Nutrition values section (hidden - will be accessible via scroll)
                        if false {
                            Divider()
                                .padding(.vertical, 8)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Nutrition Analysis")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding(.horizontal)

                                // Explanation text (shown when values differ)
                                if shouldShowUpdateButton {
                                    Text("The scanned values are different from the database. You can help improve the database by updating these values.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                        .padding(.bottom, 4)
                                }

                                // All values with labels on the left
                                if let api = apiProduct, let apiProtein = api.protein, let ocr = ocrProtein, abs(ocr - apiProtein) > 0.1 {
                                    nutritionComparisonRow(label: "Protein", apiValue: apiProtein, ocrValue: ocr, color: .blue)
                                } else if let api = apiProduct, let apiProtein = api.protein {
                                    nutritionRow(label: "Protein", value: apiProtein, color: .blue)
                                } else if let ocr = ocrProtein {
                                    nutritionRow(label: "Protein", value: ocr, color: .blue)
                                }

                                if let api = apiProduct, let apiFat = api.fat, let ocr = ocrFat, abs(ocr - apiFat) > 0.1 {
                                    nutritionComparisonRow(label: "Fat", apiValue: apiFat, ocrValue: ocr, color: .orange)
                                } else if let api = apiProduct, let apiFat = api.fat {
                                    nutritionRow(label: "Fat", value: apiFat, color: .orange)
                                } else if let ocr = ocrFat {
                                    nutritionRow(label: "Fat", value: ocr, color: .orange)
                                }

                                if let api = apiProduct, let apiFiber = api.fiber, let ocr = ocrFiber, abs(ocr - apiFiber) > 0.1 {
                                    nutritionComparisonRow(label: "Fiber", apiValue: apiFiber, ocrValue: ocr, color: .green)
                                } else if let api = apiProduct, let apiFiber = api.fiber {
                                    nutritionRow(label: "Fiber", value: apiFiber, color: .green)
                                } else if let ocr = ocrFiber {
                                    nutritionRow(label: "Fiber", value: ocr, color: .green)
                                }

                                if let api = apiProduct, let apiMoisture = api.moisture, let ocr = ocrMoisture, abs(ocr - apiMoisture) > 0.1 {
                                    nutritionComparisonRow(label: "Moisture", apiValue: apiMoisture, ocrValue: ocr, color: .cyan)
                                } else if let api = apiProduct, let apiMoisture = api.moisture {
                                    nutritionRow(label: "Moisture", value: apiMoisture, color: .cyan)
                                } else if let ocr = ocrMoisture {
                                    nutritionRow(label: "Moisture", value: ocr, color: .cyan)
                                }

                                if let api = apiProduct, let apiAsh = api.ash, let ocr = ocrAsh, abs(ocr - apiAsh) > 0.1 {
                                    nutritionComparisonRow(label: "Ash", apiValue: apiAsh, ocrValue: ocr, color: .gray)
                                } else if let api = apiProduct, let apiAsh = api.ash {
                                    nutritionRow(label: "Ash", value: apiAsh, color: .gray)
                                } else if let ocr = ocrAsh {
                                    nutritionRow(label: "Ash", value: ocr, color: .gray)
                                }

                                // Carbs meter (if all values available)
                                if let protein = (ocrProtein ?? apiProduct?.protein),
                                   let fat = (ocrFat ?? apiProduct?.fat),
                                   let fiber = (ocrFiber ?? apiProduct?.fiber),
                                   let moisture = (ocrMoisture ?? apiProduct?.moisture),
                                   let ash = (ocrAsh ?? apiProduct?.ash) {

                                    carbsMeterView(protein: protein, fat: fat, fiber: fiber, moisture: moisture, ash: ash)
                                }

                                // Update button (shown when OCR values differ from API)
                                if shouldShowUpdateButton {
                                    VStack(spacing: 8) {
                                        Button {
                                            updateDatabase()
                                        } label: {
                                            HStack {
                                                if isUploading {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                        .scaleEffect(0.8)
                                                }
                                                Text(isUploading ? "Updating..." : "Update Database")
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
                                    }
                                }
                            }
                        }

                        // New Scan button (show with nutrition values)
                        if showNutritionValues && (hasNutritionValues || productNotFound) {
                            Button {
                                resetScanner()
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("New Scan")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 40)
                        }
                        }
                        .id("form")
                    }
                    .background(Color.clear)
                    .refreshable {
                        resetScanner()
                    }
                    .onAppear {
                        scrollProxy = proxy
                        startScanning()
                    }
                    .onDisappear {
                        stopScanning()
                    }
                }

                // Barcode and Product form container (fixed at bottom)
                VStack {
                    Spacer()
                    VStack(spacing: 0) {
                        // Barcode scanner
                        HStack(alignment: .center, spacing: 0) {
                            Image(systemName: "barcode")
                                .foregroundColor(.white)
                                .imageScale(.large)
                                .frame(width: 80, alignment: .trailing)

                            if let barcode = detectedBarcode {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(barcode)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            } else {
                                LaserScannerView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 20)
                                    .padding(.leading, 8)
                            }
                        }
                        .frame(height: 20)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .animation(nil, value: detectedBarcode)

                        // Product Name field (show when barcode detected)
                        if detectedBarcode != nil {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Product")
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .trailing)

                                    if isLoadingProduct {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Loading...")
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(5)
                                    } else {
                                        TextField("Product name", text: $productName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }
                                .padding(.horizontal, 16)

                                // Brand field
                                HStack {
                                    Text("Brand")
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .trailing)

                                    if isLoadingProduct {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Loading...")
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(5)
                                    } else {
                                        TextField("Brand name", text: $brand)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.top, 12)
                            .transition(.move(edge: .bottom))
                            .id("productFields")
                        }

                        // Nutrition values section (displayed as tiles) - show when at least one value available
                        // Use optional API fields (apiFiber, etc.) to preserve nil vs 0 distinction
                        let nutritionValues: [(label: String, value: Double?, isFromOCR: Bool)] = [
                            ("Protein", ocrProtein ?? apiProduct?.apiProtein, ocrProtein != nil),
                            ("Fat", ocrFat ?? apiProduct?.apiFat, ocrFat != nil),
                            ("Fiber", ocrFiber ?? apiProduct?.apiFiber, ocrFiber != nil),
                            ("Moisture", ocrMoisture ?? apiProduct?.apiMoisture, ocrMoisture != nil),
                            ("Ash", ocrAsh ?? apiProduct?.apiAsh, ocrAsh != nil)
                        ]

                        // Only show nutrition tiles if at least one value is available
                        if nutritionValues.contains(where: { $0.value != nil }) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(nutritionValues.indices, id: \.self) { index in
                                    nutritionTile(
                                        label: nutritionValues[index].label,
                                        value: nutritionValues[index].value,
                                        isFromOCR: nutritionValues[index].isFromOCR
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, detectedBarcode != nil && !isLoadingProduct ? 12 : 0)
                            .transition(.move(edge: .bottom))
                        }

                        // Validation warnings
                        if !validationErrors.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(validationErrors.indices, id: \.self) { index in
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text(validationErrors[index].message)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.move(edge: .bottom))
                        }

                        // Carbs meter (shown when we have all 5 values from any source)
                        let protein = ocrProtein ?? apiProduct?.apiProtein
                        let fat = ocrFat ?? apiProduct?.apiFat
                        let fiber = ocrFiber ?? apiProduct?.apiFiber
                        let moisture = ocrMoisture ?? apiProduct?.apiMoisture
                        let ash = ocrAsh ?? apiProduct?.apiAsh

                        let hasAllValues = protein != nil && fat != nil && fiber != nil && moisture != nil && ash != nil

                        if hasAllValues {
                            // Calculate carbs from combined values
                            let carbs = NutritionCalculator.calculateCarbs(
                                protein: protein!,
                                fat: fat!,
                                fiber: fiber!,
                                moisture: moisture!,
                                ash: ash!
                            )
                            let carbsLevel = NutritionCalculator.getCarbsLevel(carbs: carbs)

                            VStack(spacing: 0) {
                                CarbsMeterView(
                                    carbsPercentage: carbs,
                                    carbsLevel: carbsLevel
                                )
                            }
                            .padding(.top, 16)
                            .transition(.move(edge: .bottom))
                        }
                    }
                    .padding(.bottom, 12)
                    .background(Color.black.opacity(0.5))
                    .edgesIgnoringSafeArea(.bottom)
                    .id("barcode")
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showingMultiplePhotoPicker) {
            ImagePicker(images: $selectedImages)
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                Task {
                    await processImage(image)
                }
            }
        }
        .onChange(of: selectedImages) { newImages in
            if let images = newImages, !images.isEmpty {
                print("📸 Multiple photos selected: \(images.count) images")
                print("🎬 Starting video stream simulation (0.5s per frame)")
                startImageStreamProcessing(images: images)
            }
        }
        .onChange(of: resetTrigger) { _ in
            resetScanner()
        }
        .alert("Success!", isPresented: $showUploadSuccess) {
            Button("OK", role: .cancel) {}
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

    // MARK: - View Components

    @ViewBuilder
    private func carbsMeterView(protein: Double, fat: Double, fiber: Double, moisture: Double, ash: Double) -> some View {
        let carbs = NutritionCalculator.calculateCarbs(
            protein: protein,
            fat: fat,
            fiber: fiber,
            moisture: moisture,
            ash: ash
        )
        let carbsLevel = NutritionCalculator.getCarbsLevel(carbs: carbs)

        let apiCarbs: Double? = {
            guard let api = apiProduct,
                  let protein = api.protein,
                  let fat = api.fat,
                  let fiber = api.fiber,
                  let moisture = api.moisture,
                  let ash = api.ash else { return nil }
            return NutritionCalculator.calculateCarbs(
                protein: protein,
                fat: fat,
                fiber: fiber,
                moisture: moisture,
                ash: ash
            )
        }()

        let apiCarbsLevel: CarbsLevel? = {
            guard let apiCarbs = apiCarbs else { return nil }
            return NutritionCalculator.getCarbsLevel(carbs: apiCarbs)
        }()

        Divider()
            .padding(.vertical, 8)

        CarbsMeterView(
            carbsPercentage: carbs,
            carbsLevel: carbsLevel,
            apiCarbsPercentage: apiCarbs,
            apiCarbsLevel: apiCarbsLevel
        )
        .padding()
        .padding(.bottom, 16)
    }

    private func simpleNutritionRow(label: String, value: Double, isFromOCR: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            HStack {
                Image(systemName: isFromOCR ? "camera" : "cloud")
                    .font(.caption2)
                    .foregroundColor(.white)
                Text("\(value, specifier: "%.1f")%")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }

    private func nutritionTile(label: String, value: Double?, isFromOCR: Bool) -> some View {
        let isMissing = value == nil

        return VStack(spacing: 4) {
            HStack(spacing: 2) {
                if isMissing {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 8))
                        .foregroundColor(.red.opacity(0.9))
                } else {
                    Image(systemName: isFromOCR ? "camera" : "cloud")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.7))
                }
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(isMissing ? .red.opacity(0.9) : .white.opacity(0.7))
            }

            if let value = value {
                Text("\(value, specifier: "%.1f")%")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isMissing ? Color.red.opacity(0.15) : Color.white.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isMissing ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private func nutritionRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "cloud")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("\(value, specifier: "%.1f")%")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                // Placeholder to match arrow + spacing + second box in comparison view
                Image(systemName: "arrow.right")
                    .foregroundColor(.clear)
                    .fontWeight(.bold)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private func nutritionComparisonRow(label: String, apiValue: Double, ocrValue: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)

            HStack(spacing: 12) {
                // API value
                HStack {
                    Image(systemName: "cloud")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(apiValue, specifier: "%.1f")%")
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Image(systemName: "arrow.right")
                    .foregroundColor(.green)
                    .fontWeight(.bold)

                // OCR value (new/scanned)
                HStack {
                    Image(systemName: "camera")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("\(ocrValue, specifier: "%.1f")%")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 2)
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helper Properties

    /// Determines food type, optionally using scanned moisture if API data unavailable
    private func determineFoodType(scannedMoisture: Double? = nil) -> Bool {
        // If we have API data, use isWetFood (checks categories, keywords, API moisture)
        if apiProduct != nil {
            return isWetFood
        }

        // No API data - use scanned moisture if available
        if let moisture = scannedMoisture {
            return moisture > 50.0
        }

        // Default to wet food (broader ranges, safer)
        return true
    }

    private var isWetFood: Bool {
        // 1. Check API categories first (most reliable)
        if let tags = apiProduct?.categoriesTags {
            // Check for wet food tags
            if tags.contains(where: { $0.contains("wet") }) {
                return true
            }
            // Check for dry food tags
            if tags.contains(where: { $0.contains("dry") }) {
                return false
            }
        }

        // 2. Check product name/brand for keywords
        let productText = (productName + " " + brand).lowercased()
        let wetKeywords = ["canned", "wet", "pâté", "pate", "gravy", "mousse", "terrine", "loaf", "pouch"]
        let dryKeywords = ["kibble", "dry", "biscuit", "crunch"]

        if wetKeywords.contains(where: { productText.contains($0) }) {
            return true
        }

        if dryKeywords.contains(where: { productText.contains($0) }) {
            return false
        }

        // 3. Fallback to API moisture (reliable, doesn't change)
        if let moisture = apiProduct?.moisture {
            return moisture > 50.0
        }

        // 4. Default: assume wet food (broader validation ranges, safer default)
        return true
    }

    private func getConsensusValue(from values: [Double], validator: ((Double) -> Bool)? = nil) -> Double? {
        guard !values.isEmpty else { return nil }

        // Filter valid values using custom validator or default
        let validValues = values.filter { value in
            if let validator = validator {
                return validator(value)
            }
            return value > 0.1 && value < 100.0
        }
        guard !validValues.isEmpty else { return nil }

        // If only one value, show it immediately (progressive display)
        if validValues.count == 1 {
            NSLog("FITCAT: Single detection: \(String(format: "%.1f", validValues[0]))% (will update with better consensus)")
            return validValues[0]
        }

        // Count frequency of each value (treating values within 0.1 as identical)
        // OCR errors are discrete (missing decimal, wrong digit), not continuous noise
        // So we pick MODE (most frequent), not MEAN (average)
        var frequencyMap: [String: (value: Double, count: Int)] = [:]

        for value in validValues {
            // Round to 1 decimal place to group nearly identical values
            let key = String(format: "%.1f", value)
            if let existing = frequencyMap[key] {
                frequencyMap[key] = (existing.value, existing.count + 1)
            } else {
                frequencyMap[key] = (value, 1)
            }
        }

        // Find the most frequent value (mode) - this is the "best" version
        let mostFrequent = frequencyMap.values.max(by: { $0.count < $1.count })!

        // Log confidence
        let confidence = Double(mostFrequent.count) / Double(validValues.count) * 100
        NSLog("FITCAT: Consensus from \(values.map { String(format: "%.1f", $0) }.joined(separator: ", ")): \(String(format: "%.1f", mostFrequent.value))% (appears \(mostFrequent.count)/\(validValues.count) times, \(Int(confidence))% confidence)")

        return mostFrequent.value
    }

    private func isValidProtein(_ protein: Double, moisture: Double? = nil, logError: Bool = true) -> Bool {
        let valid: Bool
        let range: String
        let wetFood = determineFoodType(scannedMoisture: moisture)

        if wetFood {
            // Wet food: protein is typically 7-15%
            valid = protein >= 5.0 && protein <= 20.0
            range = "5-20%"
        } else {
            // Dry food: protein is typically 30-50%
            valid = protein >= 25.0 && protein <= 60.0
            range = "25-60%"
        }

        if logError && !valid {
            NSLog("FITCAT: Protein \(protein)% outside valid range for \(wetFood ? "wet" : "dry") food (\(range))")
        }

        return valid
    }

    private func isValidFat(_ fat: Double, moisture: Double? = nil, logError: Bool = true) -> Bool {
        let valid: Bool
        let range: String
        let wetFood = determineFoodType(scannedMoisture: moisture)

        if wetFood {
            // Wet food: fat is typically 2-10%
            valid = fat >= 1.0 && fat <= 15.0
            range = "1-15%"
        } else {
            // Dry food: fat is typically 10-25%
            valid = fat >= 8.0 && fat <= 30.0
            range = "8-30%"
        }

        if logError && !valid {
            NSLog("FITCAT: Fat \(fat)% outside valid range for \(wetFood ? "wet" : "dry") food (\(range))")
        }

        return valid
    }

    private func isValidFiber(_ fiber: Double, moisture: Double? = nil, logError: Bool = true) -> Bool {
        let valid: Bool
        let range: String
        let wetFood = determineFoodType(scannedMoisture: moisture)

        if wetFood {
            // Wet food: fiber is typically 0.4-3.0%, but can be 0% in pure meat products
            valid = fiber >= 0.0 && fiber <= 3.0
            range = "0-3%"
        } else {
            // Dry food: fiber is typically 1.5-10%
            valid = fiber >= 1.0 && fiber <= 10.0
            range = "1-10%"
        }

        if logError && !valid {
            NSLog("FITCAT: Fiber \(fiber)% outside valid range for \(wetFood ? "wet" : "dry") food (\(range))")
        }

        return valid
    }

    private func isValidMoisture(_ moisture: Double, logError: Bool = true) -> Bool {
        // If we have API product data, validate against expected food type
        if apiProduct != nil {
            let expectedWetFood = isWetFood

            if expectedWetFood {
                // Wet food: 70-90%
                let valid = moisture >= 70.0 && moisture <= 90.0
                if logError && !valid {
                    NSLog("FITCAT: Moisture \(moisture)% outside valid range for wet food (70-90%)")
                }
                return valid
            } else {
                // Dry food: 6-12%
                let valid = moisture >= 6.0 && moisture <= 12.0
                if logError && !valid {
                    NSLog("FITCAT: Moisture \(moisture)% outside valid range for dry food (6-12%)")
                }
                return valid
            }
        }

        // No API data - accept any reasonable moisture value
        // This allows dry (6-12%), semi-moist (15-30%), or wet (70-90%)
        let valid = moisture >= 6.0 && moisture < 100.0

        if logError && !valid {
            NSLog("FITCAT: Moisture \(moisture)% outside valid range (6-100%)")
        }

        return valid
    }

    private func isValidAsh(_ ash: Double, moisture: Double? = nil, logError: Bool = true) -> Bool {
        let valid: Bool
        let range: String
        let wetFood = determineFoodType(scannedMoisture: moisture)

        if wetFood {
            valid = ash >= 1.5 && ash <= 4.0
            range = "1.5-4%"
        } else {
            valid = ash >= 3.5 && ash <= 12.0
            range = "3.5-12%"
        }

        if logError && !valid {
            NSLog("FITCAT: Ash \(ash)% outside valid range for \(wetFood ? "wet" : "dry") food (\(range))")
        }

        return valid
    }

    // MARK: - Scanner Functions

    private func startScanning() {
        guard !isSimulator else { return }

        cameraModel.startSession()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.captureAndProcess()
        }

        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.captureAndProcess()
        }
    }

    private func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        imageProcessingTimer?.invalidate()
        cameraModel.stopSession()
    }

    private func captureAndProcess() {
        guard !isProcessing else { return }

        isProcessing = true
        cameraModel.capturePhoto { image in
            Task {
                await self.processImage(image)
            }
        }
    }

    private func startImageStreamProcessing(images: [UIImage]) {
        imageProcessingTimer?.invalidate()
        imageProcessingIndex = 0

        imageProcessingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard self.imageProcessingIndex < images.count else {
                timer.invalidate()
                print("🎬 Video stream simulation completed")
                return
            }

            let image = images[self.imageProcessingIndex]
            print("🎬 Processing frame \(self.imageProcessingIndex + 1)/\(images.count)")

            Task {
                await self.processImage(image)
            }

            self.imageProcessingIndex += 1
        }
    }

    private func processImage(_ image: UIImage) async {
        print("🔍 processImage called")
        let ocrService = OCRService()
        let parser = NutritionParser()

        // Detect barcode only if not already detected
        if detectedBarcode == nil {
            if let cgImage = image.cgImage {
                print("🔍 Detecting barcode in image...")
                detectBarcode(in: cgImage)
            }
        }

        do {
            print("🔍 Starting OCR...")
            let texts = try await ocrService.recognizeText(from: image)
            print("✅ OCR detected \(texts.count) text lines")

            let nutrition = parser.parseNutrition(from: texts)
            print("Parsed nutrition: p=\(nutrition.protein?.description ?? "nil"), f=\(nutrition.fat?.description ?? "nil"), fi=\(nutrition.fiber?.description ?? "nil"), m=\(nutrition.moisture?.description ?? "nil"), a=\(nutrition.ash?.description ?? "nil")")

            // Try to extract barcode from OCR text
            if let barcodeFromOCR = extractBarcodeFromText(texts) {
                await MainActor.run {
                    if self.detectedBarcode == nil {
                        print("✅ Extracted barcode from OCR text: \(barcodeFromOCR)")
                        self.detectedBarcode = barcodeFromOCR
                        self.checkDatabaseForBarcode(barcodeFromOCR)
                    } else if barcodeFromOCR.count > self.detectedBarcode!.count {
                        print("⬆️ Upgrading barcode from \(self.detectedBarcode!) to \(barcodeFromOCR)")
                        self.detectedBarcode = barcodeFromOCR
                        self.checkDatabaseForBarcode(barcodeFromOCR)
                    }
                }
            }

            // Store OCR nutrition values with validation
            await MainActor.run {
                if let protein = nutrition.protein {
                    if self.isValidProtein(protein, moisture: nutrition.moisture, logError: true) {
                        self.ocrProtein = protein
                    } else {
                        NSLog("FITCAT: Rejecting invalid protein value: \(protein)%")
                    }
                }
                if let fat = nutrition.fat {
                    if self.isValidFat(fat, moisture: nutrition.moisture, logError: true) {
                        self.ocrFat = fat
                    } else {
                        NSLog("FITCAT: Rejecting invalid fat value: \(fat)%")
                    }
                }
                if let fiber = nutrition.fiber {
                    if self.isValidFiber(fiber, moisture: nutrition.moisture, logError: true) {
                        self.ocrFiber = fiber
                    } else {
                        NSLog("FITCAT: Rejecting invalid fiber value: \(fiber)%")
                    }
                }
                if let moisture = nutrition.moisture {
                    if self.isValidMoisture(moisture, logError: true) {
                        self.ocrMoisture = moisture
                    } else {
                        NSLog("FITCAT: Rejecting invalid moisture value: \(moisture)%")
                    }
                }
                if let ash = nutrition.ash {
                    if self.isValidAsh(ash, moisture: nutrition.moisture, logError: true) {
                        self.ocrAsh = ash
                    } else {
                        NSLog("FITCAT: Rejecting invalid ash value: \(ash)%")
                    }
                }

                self.isProcessing = false
            }
        } catch {
            print("OCR error: \(error)")
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }

    private func detectBarcode(in cgImage: CGImage) {
        let request = VNDetectBarcodesRequest { request, error in
            guard let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first,
                  let payloadString = firstBarcode.payloadStringValue else {
                return
            }

            DispatchQueue.main.async {
                guard self.detectedBarcode != payloadString else { return }

                self.detectedBarcode = payloadString
                print("✅ Detected barcode: \(payloadString)")
                self.checkDatabaseForBarcode(payloadString)
            }
        }

        request.symbologies = [.upce, .ean8, .ean13, .code128, .code39, .code93, .i2of5, .itf14, .pdf417, .qr, .aztec]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    private func extractBarcodeFromText(_ texts: [String]) -> String? {
        print("🔍 Trying to extract barcode from OCR text...")

        var candidates: [String] = []

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespaces)

            // Pattern 1: Standard EAN-13 format: 1 digit + 6 digits + 6 digits
            let pattern1 = #"(\d)\s*(\d{6})\s*(\d{6})"#
            if let regex = try? NSRegularExpression(pattern: pattern1) {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                let matches = regex.matches(in: trimmed, range: range)

                for match in matches {
                    if match.numberOfRanges == 4 {
                        var parts: [String] = []
                        for i in 1...3 {
                            if let r = Range(match.range(at: i), in: trimmed) {
                                parts.append(String(trimmed[r]))
                            }
                        }
                        if parts.count == 3 {
                            let barcode = parts.joined()
                            if validateBarcodeCheckDigit(barcode) && !candidates.contains(barcode) {
                                candidates.append(barcode)
                                print("   Found valid barcode: \(barcode) ✓")
                            }
                        }
                    }
                }
            }

            // Pattern 2: 12-digit fallback
            let digitsOnly = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if digitsOnly.count == 12 {
                let prefixPriority = [4, 0, 1, 2, 3, 5, 6, 7, 8, 9]
                for prefix in prefixPriority {
                    let barcode = "\(prefix)" + digitsOnly
                    if validateBarcodeCheckDigit(barcode) && !candidates.contains(barcode) {
                        candidates.append(barcode)
                        print("   Found valid barcode (reconstructed with prefix \(prefix)): \(barcode) ✓")
                        break
                    }
                }
            }
        }

        if !candidates.isEmpty {
            let preferredBarcode = candidates.first { $0.hasPrefix("4") } ?? candidates.first!
            print("✅ Selected barcode: \(preferredBarcode)")
            return preferredBarcode
        }

        print("⚠️ No valid barcode found in OCR text")
        return nil
    }

    private func validateBarcodeCheckDigit(_ barcode: String) -> Bool {
        let digits = barcode.compactMap { $0.wholeNumberValue }
        guard digits.count == barcode.count else { return false }
        guard [8, 12, 13].contains(digits.count) else { return false }

        var sum = 0
        for i in 0..<(digits.count - 1) {
            let multiplier = (i % 2 == 0) ? 1 : 3
            sum += digits[i] * multiplier
        }

        let calculatedCheckDigit = (10 - (sum % 10)) % 10
        let actualCheckDigit = digits[digits.count - 1]

        return calculatedCheckDigit == actualCheckDigit
    }

    private func checkDatabaseForBarcode(_ barcode: String) {
        // Record when scanning started
        if scanStartTime == nil {
            scanStartTime = Date()
        }

        Task {
            await queryOpenPetFoodFacts(barcode: barcode)
        }
    }

    private func queryOpenPetFoodFacts(barcode: String) async {
        print("Querying Open Pet Food Facts for barcode: \(barcode)")

        let apiStart = Date()

        await MainActor.run {
            isLoadingProduct = true
            apiStartTime = apiStart
        }

        let service = OpenPetFoodFactsService()

        do {
            if let product = try await service.fetchProduct(barcode: barcode) {
                print("Found product in Open Pet Food Facts: \(product.productName)")

                // Ensure minimum display times
                await ensureMinimumDisplayTimes(scanStart: scanStartTime, apiStart: apiStart)

                await MainActor.run {
                    self.apiProduct = product
                    self.productName = product.productName
                    self.brand = product.brand
                    self.productNotFound = false
                    self.isLoadingProduct = false

                    // Keep scanning for OCR if not all nutrition values are present
                    let hasAllValues = self.ocrProtein != nil && self.ocrFat != nil &&
                                      self.ocrFiber != nil && self.ocrMoisture != nil && self.ocrAsh != nil
                    if hasAllValues {
                        stopScanning()
                    }
                }
            } else {
                print("Product not found in Open Pet Food Facts")

                // Ensure minimum display times
                await ensureMinimumDisplayTimes(scanStart: scanStartTime, apiStart: apiStart)

                await MainActor.run {
                    self.isLoadingProduct = false
                    self.productNotFound = true
                }
            }
        } catch {
            print("Open Pet Food Facts API error: \(error)")

            // Ensure minimum display times
            await ensureMinimumDisplayTimes(scanStart: scanStartTime, apiStart: apiStart)

            await MainActor.run {
                self.isLoadingProduct = false
                self.productNotFound = true
            }
        }
    }

    private func ensureMinimumDisplayTimes(scanStart: Date?, apiStart: Date) async {
        var delays: [TimeInterval] = []

        // Check if we need to wait for minimum scanning time
        if let start = scanStart {
            let scanElapsed = Date().timeIntervalSince(start)
            let scanRemaining = APIConfig.minimumScanningDisplayTime - scanElapsed
            if scanRemaining > 0 {
                delays.append(scanRemaining)
            }
        }

        // Check if we need to wait for minimum loading time
        let apiElapsed = Date().timeIntervalSince(apiStart)
        let apiRemaining = APIConfig.minimumLoadingDisplayTime - apiElapsed
        if apiRemaining > 0 {
            delays.append(apiRemaining)
        }

        // Wait for the longest required delay
        if let maxDelay = delays.max(), maxDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(maxDelay * 1_000_000_000))
        }
    }

    private func updateDatabase() {
        guard let api = apiProduct, let barcode = detectedBarcode else { return }

        var updatedProduct = api

        // Update with OCR values where they differ
        if let ocr = ocrProtein, let apiProtein = api.protein, abs(ocr - apiProtein) > 0.1 {
            updatedProduct.protein = ocr
        }
        if let ocr = ocrFat, let apiFat = api.fat, abs(ocr - apiFat) > 0.1 {
            updatedProduct.fat = ocr
        }
        if let ocr = ocrFiber, let apiFiber = api.fiber, abs(ocr - apiFiber) > 0.1 {
            updatedProduct.fiber = ocr
        }
        if let ocr = ocrMoisture, let apiMoisture = api.moisture, abs(ocr - apiMoisture) > 0.1 {
            updatedProduct.moisture = ocr
        }
        if let ocr = ocrAsh, let apiAsh = api.ash, abs(ocr - apiAsh) > 0.1 {
            updatedProduct.ash = ocr
        }

        Task {
            isUploading = true

            do {
                let service = OpenPetFoodFactsService()
                let success = try await service.uploadProduct(updatedProduct)

                await MainActor.run {
                    isUploading = false

                    if success {
                        // Update API product with new values and clear OCR values
                        self.apiProduct = updatedProduct
                        self.ocrProtein = nil
                        self.ocrFat = nil
                        self.ocrFiber = nil
                        self.ocrMoisture = nil
                        self.ocrAsh = nil

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

    private func resetScanner() {
        // Clear all state
        detectedBarcode = nil
        productName = ""
        brand = ""
        apiProduct = nil
        ocrProtein = nil
        ocrFat = nil
        ocrFiber = nil
        ocrMoisture = nil
        ocrAsh = nil
        isLoadingProduct = false
        productNotFound = false
        showNutritionValues = false
        scanStartTime = nil
        apiStartTime = nil

        // Scroll back to camera
        withAnimation {
            scrollProxy?.scrollTo("camera", anchor: .top)
        }

        // Restart scanning if not simulator
        if !isSimulator {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                startScanning()
            }
        }
    }
}

// MARK: - Camera Model
class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    private var output = AVCapturePhotoOutput()
    private var photoCompletion: ((UIImage) -> Void)?

    func startSession() {
        if session.isRunning {
            return
        }

        if session.inputs.isEmpty {
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        guard session.isRunning else {
            return
        }

        self.photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }

        photoCompletion?(image)
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds

        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Laser Scanner View
struct LaserScannerView: View {
    @State private var animationOffset: CGFloat = -1.0

    var body: some View {
        ZStack {
            // Fading background
            Rectangle()
                .fill(Color.black.opacity(0.3))

            GeometryReader { geometry in
                // Moving laser line
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.0),
                                Color.red.opacity(0.8),
                                Color.red,
                                Color.red.opacity(0.8),
                                Color.red.opacity(0.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 40, height: geometry.size.height)
                    .offset(x: (geometry.size.width - 40) * (animationOffset + 1) / 2)
                    .onAppear {
                        withAnimation(
                            Animation.linear(duration: 1.5)
                                .repeatForever(autoreverses: true)
                        ) {
                            animationOffset = 1.0
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .overlay(
            Rectangle()
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        )
    }
}
