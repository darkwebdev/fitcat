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

        if let ocr = ocrProtein, abs(ocr - api.protein) > 0.1 { return true }
        if let ocr = ocrFat, abs(ocr - api.fat) > 0.1 { return true }
        if let ocr = ocrFiber, abs(ocr - api.fiber) > 0.1 { return true }
        if let ocr = ocrMoisture, abs(ocr - api.moisture) > 0.1 { return true }
        if let ocr = ocrAsh, abs(ocr - api.ash) > 0.1 { return true }

        return false
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .onTapGesture {
                        showingMultiplePhotoPicker = true
                    }
                } else {
                    CameraPreview(camera: cameraModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Scrollable content overlay
                ScrollViewReader { proxy in
                    ScrollView {
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
                                if let api = apiProduct, let ocr = ocrProtein, abs(ocr - api.protein) > 0.1 {
                                    nutritionComparisonRow(label: "Protein", apiValue: api.protein, ocrValue: ocr, color: .blue)
                                } else if let api = apiProduct {
                                    nutritionRow(label: "Protein", value: api.protein, color: .blue)
                                } else if let ocr = ocrProtein {
                                    nutritionRow(label: "Protein", value: ocr, color: .blue)
                                }

                                if let api = apiProduct, let ocr = ocrFat, abs(ocr - api.fat) > 0.1 {
                                    nutritionComparisonRow(label: "Fat", apiValue: api.fat, ocrValue: ocr, color: .orange)
                                } else if let api = apiProduct {
                                    nutritionRow(label: "Fat", value: api.fat, color: .orange)
                                } else if let ocr = ocrFat {
                                    nutritionRow(label: "Fat", value: ocr, color: .orange)
                                }

                                if let api = apiProduct, let ocr = ocrFiber, abs(ocr - api.fiber) > 0.1 {
                                    nutritionComparisonRow(label: "Fiber", apiValue: api.fiber, ocrValue: ocr, color: .green)
                                } else if let api = apiProduct {
                                    nutritionRow(label: "Fiber", value: api.fiber, color: .green)
                                } else if let ocr = ocrFiber {
                                    nutritionRow(label: "Fiber", value: ocr, color: .green)
                                }

                                if let api = apiProduct, let ocr = ocrMoisture, abs(ocr - api.moisture) > 0.1 {
                                    nutritionComparisonRow(label: "Moisture", apiValue: api.moisture, ocrValue: ocr, color: .cyan)
                                } else if let api = apiProduct {
                                    nutritionRow(label: "Moisture", value: api.moisture, color: .cyan)
                                } else if let ocr = ocrMoisture {
                                    nutritionRow(label: "Moisture", value: ocr, color: .cyan)
                                }

                                if let api = apiProduct, let ocr = ocrAsh, abs(ocr - api.ash) > 0.1 {
                                    nutritionComparisonRow(label: "Ash", apiValue: api.ash, ocrValue: ocr, color: .gray)
                                } else if let api = apiProduct {
                                    nutritionRow(label: "Ash", value: api.ash, color: .gray)
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

                        // Nutrition values section (individual fields appear as detected)
                        if let value = ocrProtein ?? apiProduct?.protein {
                            simpleNutritionRow(label: "Protein", value: value, isFromOCR: ocrProtein != nil)
                                .padding(.horizontal, 16)
                                .padding(.top, detectedBarcode != nil && !isLoadingProduct ? 12 : 0)
                                .transition(.move(edge: .bottom))
                        }

                        if let value = ocrFat ?? apiProduct?.fat {
                            simpleNutritionRow(label: "Fat", value: value, isFromOCR: ocrFat != nil)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .transition(.move(edge: .bottom))
                        }

                        if let value = ocrFiber ?? apiProduct?.fiber {
                            simpleNutritionRow(label: "Fiber", value: value, isFromOCR: ocrFiber != nil)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .transition(.move(edge: .bottom))
                        }

                        if let value = ocrMoisture ?? apiProduct?.moisture {
                            simpleNutritionRow(label: "Moisture", value: value, isFromOCR: ocrMoisture != nil)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .transition(.move(edge: .bottom))
                        }

                        if let value = ocrAsh ?? apiProduct?.ash {
                            simpleNutritionRow(label: "Ash", value: value, isFromOCR: ocrAsh != nil)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
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
            guard let api = apiProduct else { return nil }
            return NutritionCalculator.calculateCarbs(
                protein: api.protein,
                fat: api.fat,
                fiber: api.fiber,
                moisture: api.moisture,
                ash: api.ash
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

    private var isWetFood: Bool {
        let productText = (productName + " " + brand).lowercased()
        let wetKeywords = ["canned", "wet", "pâté", "pate", "gravy", "mousse", "terrine", "loaf", "pouch"]
        let dryKeywords = ["kibble", "dry", "biscuit", "crunch"]

        // Check for wet food keywords
        if wetKeywords.contains(where: { productText.contains($0) }) {
            return true
        }

        // Check for dry food keywords
        if dryKeywords.contains(where: { productText.contains($0) }) {
            return false
        }

        // If no keywords found, use API moisture only (more reliable than OCR)
        // Wet/dry is a product property that doesn't change, even if nutrition numbers are outdated
        if let moisture = apiProduct?.moisture {
            return moisture > 50.0
        }

        // Default: assume wet food (broader validation ranges, safer default)
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

            // Store OCR nutrition values
            await MainActor.run {
                if let protein = nutrition.protein {
                    self.ocrProtein = protein
                }
                if let fat = nutrition.fat {
                    self.ocrFat = fat
                }
                if let fiber = nutrition.fiber {
                    self.ocrFiber = fiber
                }
                if let moisture = nutrition.moisture {
                    self.ocrMoisture = moisture
                }
                if let ash = nutrition.ash {
                    self.ocrAsh = ash
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
        if let ocr = ocrProtein, abs(ocr - api.protein) > 0.1 {
            updatedProduct.protein = ocr
        }
        if let ocr = ocrFat, abs(ocr - api.fat) > 0.1 {
            updatedProduct.fat = ocr
        }
        if let ocr = ocrFiber, abs(ocr - api.fiber) > 0.1 {
            updatedProduct.fiber = ocr
        }
        if let ocr = ocrMoisture, abs(ocr - api.moisture) > 0.1 {
            updatedProduct.moisture = ocr
        }
        if let ocr = ocrAsh, abs(ocr - api.ash) > 0.1 {
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
