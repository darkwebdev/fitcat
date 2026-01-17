//
//  OCRScannerView.swift
//  FitCat
//
//  OCR scanner for nutrition labels
//

import SwiftUI
import AVFoundation
import UIKit
import Vision

struct OCRScannerView: View {
    let onNutritionScanned: (NutritionInfo) -> Void
    @Binding var resetTrigger: Int

    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var detectedNutrition: NutritionInfo?
    @State private var detectedBarcode: String?
    @State private var lastOCRText: [String] = []
    @StateObject private var cameraModel = CameraModel()
    @State private var scanTimer: Timer?
    @State private var scanCount = 0

    // Editable text fields
    @State private var productName = ""
    @State private var brand = ""
    @State private var proteinText = ""
    @State private var fatText = ""
    @State private var fiberText = ""
    @State private var moistureText = ""
    @State private var ashText = ""

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showProductDetail = false
    @State private var existingProduct: Product?
    @State private var isLoadingFromAPI = false
    @State private var apiStatusMessage = ""
    @State private var isUploading = false
    @State private var showUploadSuccess = false
    @State private var uploadError: Error?
    @State private var showingPhotoPicker = false
    @State private var showingMultiplePhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedImages: [UIImage]?
    @State private var imageProcessingIndex = 0
    @State private var imageProcessingTimer: Timer?

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    init(resetTrigger: Binding<Int>, onNutritionScanned: @escaping (NutritionInfo) -> Void = { _ in }) {
        self._resetTrigger = resetTrigger
        self.onNutritionScanned = onNutritionScanned
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Top area - camera or meter (max 50% of screen)
                    ZStack {
                if allValuesDetected, let nutrition = currentNutrition {
                    // Show carbs meter when all values are detected
                    let carbs = NutritionCalculator.calculateCarbs(
                        protein: nutrition.protein!,
                        fat: nutrition.fat!,
                        fiber: nutrition.fiber!,
                        moisture: nutrition.moisture!,
                        ash: nutrition.ash!
                    )
                    let carbsLevel = NutritionCalculator.getCarbsLevel(carbs: carbs)

                    CarbsMeterView(carbsPercentage: carbs, carbsLevel: carbsLevel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemGroupedBackground))
                        .padding()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                } else {
                    ZStack {
                        // Camera preview or simulator placeholder
                        if isSimulator {
                            VStack(spacing: 20) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.5))

                                Text("Running in Simulator")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("Use photo picker below")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.8))
                        } else {
                            CameraPreview(camera: cameraModel)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 1.1).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                ))
                        }

                        // Photo picker buttons (available on both simulator and device)
                        VStack {
                            Spacer()
                            HStack {
                                #if targetEnvironment(simulator)
                                // Multiple images button (simulator only - simulates video stream)
                                Button {
                                    showingMultiplePhotoPicker = true
                                } label: {
                                    Image(systemName: "photo.stack.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.purple)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .padding(.leading)
                                #endif

                                Spacer()

                                // Single image button
                                Button {
                                    showingPhotoPicker = true
                                } label: {
                                    Image(systemName: "photo.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height * 0.5)

            // Bottom form
            VStack(spacing: 12) {
                    // Nutrition values and product info
                    VStack(spacing: 8) {
                        nutritionInputRow("Protein", $proteinText)
                        nutritionInputRow("Fat", $fatText)
                        nutritionInputRow("Fiber", $fiberText)
                        nutritionInputRow("Moisture", $moistureText)
                        nutritionInputRow("Ash", $ashText)

                        Divider().background(Color.white.opacity(0.3))
                            .padding(.vertical, 4)

                        HStack {
                            Image(systemName: "barcode")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 100, alignment: .leading)
                                .font(.subheadline)

                            if let barcode = detectedBarcode {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(barcode)
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                            } else {
                                Text("Not detected")
                                    .foregroundColor(.white.opacity(0.5))
                                    .italic()
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .font(.subheadline)

                        if isLoadingFromAPI {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text(apiStatusMessage)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 8)
                        } else if !apiStatusMessage.isEmpty {
                            Text(apiStatusMessage)
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 4)
                        }

                        textInputRow("Product Name", $productName)
                        textInputRow("Brand", $brand)
                    }

                    // Upload to API button
                    if allValuesDetected && detectedBarcode != nil {
                        Button {
                            uploadToAPI()
                        } label: {
                            HStack {
                                if isUploading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isUploading ? "Uploading..." : "Save Product")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isFormValid && !isUploading ? Color.green : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || isUploading)
                        .padding(.top, 12)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.8))
                }
            }
            .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success!", isPresented: $showUploadSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Product uploaded to Open Pet Food Facts. Thank you for contributing!")
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showingMultiplePhotoPicker) {
            ImagePicker(images: $selectedImages)
        }
        .onChange(of: selectedImage) { newImage in
            print("📸 Photo selected")
            if let image = newImage {
                print("📸 Image size: \(image.size)")
                Task {
                    print("📸 Starting to process image...")
                    await processImage(image)
                }
            } else {
                print("📸 No image selected")
            }
        }
        .onChange(of: selectedImages) { newImages in
            if let images = newImages, !images.isEmpty {
                print("📸 Multiple photos selected: \(images.count) images")
                print("🎬 Starting video stream simulation (0.5s per frame)")
                startImageStreamProcessing(images: images)
            }
        }
        .sheet(isPresented: $showProductDetail) {
            if let product = existingProduct {
                NavigationView {
                    ProductDetailView(product: product)
                }
            }
        }
        .onAppear {
            // Clear all fields on new scan
            clearAllFields()

            if !isSimulator {
                cameraModel.startSession()
                startContinuousScanning()
            }
        }
        .onDisappear {
            if !isSimulator {
                cameraModel.stopSession()
                stopContinuousScanning()
            }
            imageProcessingTimer?.invalidate()
        }
        .onChange(of: resetTrigger) { _ in
            // Reset scanner when trigger changes
            clearAllFields()
            if !isSimulator {
                cameraModel.stopSession()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cameraModel.startSession()
                    startContinuousScanning()
                }
            }
        }
    }

    private var allValuesDetected: Bool {
        return parseNumber(proteinText) != nil &&
               parseNumber(fatText) != nil &&
               parseNumber(fiberText) != nil &&
               parseNumber(moistureText) != nil &&
               parseNumber(ashText) != nil
    }

    private var currentNutrition: NutritionInfo? {
        guard let protein = parseNumber(proteinText),
              let fat = parseNumber(fatText),
              let fiber = parseNumber(fiberText),
              let moisture = parseNumber(moistureText),
              let ash = parseNumber(ashText) else {
            return nil
        }
        return NutritionInfo(
            protein: protein,
            fat: fat,
            fiber: fiber,
            moisture: moisture,
            ash: ash
        )
    }

    private func parseNumber(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func clearAllFields() {
        productName = ""
        brand = ""
        proteinText = ""
        fatText = ""
        fiberText = ""
        moistureText = ""
        ashText = ""
        detectedBarcode = nil
        detectedNutrition = nil
        scanCount = 0
    }

    private func textInputRow(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, alignment: .leading)

            TextField("", text: text)
                .foregroundColor(.white)
                .fontWeight(.semibold)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
        }
        .font(.subheadline)
    }

    private func nutritionInputRow(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)

            TextField("0.0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.white)
                .fontWeight(.semibold)
                .frame(width: 60)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)

            Text("%")
                .foregroundColor(.white.opacity(0.5))
        }
        .font(.subheadline)
    }

    private var isFormValid: Bool {
        !productName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !brand.trimmingCharacters(in: .whitespaces).isEmpty &&
        allValuesDetected
    }

    private func uploadToAPI() {
        guard let protein = parseNumber(proteinText),
              let fat = parseNumber(fatText),
              let fiber = parseNumber(fiberText),
              let moisture = parseNumber(moistureText),
              let ash = parseNumber(ashText) else {
            return
        }

        let product = Product(
            id: UUID(),
            barcode: detectedBarcode,
            productName: productName.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            protein: protein,
            fat: fat,
            fiber: fiber,
            moisture: moisture,
            ash: ash,
            servingSize: nil,
            createdAt: Date(),
            updatedAt: Date(),
            source: .local
        )

        Task {
            isUploading = true

            do {
                let service = OpenPetFoodFactsService()
                let success = try await service.uploadProduct(product)

                await MainActor.run {
                    isUploading = false

                    if success {
                        showUploadSuccess = true
                        // Dismiss after showing success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } else {
                        errorMessage = "Upload failed. Please try again."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func nutritionRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f%%", value))
                .fontWeight(.semibold)
        }
    }

    private func startContinuousScanning() {
        print("Starting continuous scanning...")

        // Delay first scan to allow camera session to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.captureAndProcess()
        }

        // Then scan every 0.5 seconds
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.captureAndProcess()
        }
    }

    private func stopContinuousScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
    }

    private func captureAndProcess() {
        guard !isProcessing else {
            print("Skipping scan - already processing")
            return
        }

        print("Starting scan #\(scanCount + 1)")
        isProcessing = true

        cameraModel.capturePhoto { image in
            print("Photo captured, processing...")
            Task {
                await self.processImage(image)
            }
        }
    }

    private func startImageStreamProcessing(images: [UIImage]) {
        // Stop any existing timer
        imageProcessingTimer?.invalidate()
        imageProcessingIndex = 0

        // Process images sequentially with 0.5s delay (simulating video frames)
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
            } else {
                print("⚠️ Could not get CGImage from UIImage")
            }
        } else {
            print("ℹ️ Barcode already detected (\(detectedBarcode!)), skipping barcode detection")
        }

        do {
            print("🔍 Starting OCR...")
            let texts = try await ocrService.recognizeText(from: image)
            print("✅ OCR detected \(texts.count) text lines")
            if texts.count > 0 {
                print("First few lines: \(texts.prefix(5).joined(separator: ", "))")
            }

            let nutrition = parser.parseNutrition(from: texts)
            print("Parsed nutrition: p=\(nutrition.protein?.description ?? "nil"), f=\(nutrition.fat?.description ?? "nil"), fi=\(nutrition.fiber?.description ?? "nil"), m=\(nutrition.moisture?.description ?? "nil"), a=\(nutrition.ash?.description ?? "nil")")

            // Store OCR nutrition for potential use/merging with database data
            await MainActor.run {
                self.detectedNutrition = nutrition
            }

            // Try to extract barcode from OCR text (fallback for simulator)
            if let barcodeFromOCR = extractBarcodeFromText(texts) {
                await MainActor.run {
                    // If no barcode yet, use this one
                    if self.detectedBarcode == nil {
                        print("✅ Extracted barcode from OCR text: \(barcodeFromOCR)")
                        self.detectedBarcode = barcodeFromOCR
                        self.checkDatabaseForBarcode(barcodeFromOCR)
                    }
                    // If we have a barcode but this one is longer (more likely to be correct), upgrade to it
                    else if barcodeFromOCR.count > self.detectedBarcode!.count {
                        print("⬆️ Upgrading barcode from \(self.detectedBarcode!) (\(self.detectedBarcode!.count) digits) to \(barcodeFromOCR) (\(barcodeFromOCR.count) digits)")
                        self.detectedBarcode = barcodeFromOCR
                        self.checkDatabaseForBarcode(barcodeFromOCR)
                    } else {
                        print("ℹ️ Barcode already set (\(self.detectedBarcode!)), ignoring shorter/same length barcode: \(barcodeFromOCR)")
                    }
                }
            }

            await MainActor.run {
                self.isProcessing = false
                self.scanCount += 1

                // Merge new nutrition values with existing ones (accumulate, don't replace)
                var accumulated = self.detectedNutrition ?? NutritionInfo(
                    protein: nil,
                    fat: nil,
                    fiber: nil,
                    moisture: nil,
                    ash: nil
                )

                // Only update fields that have new values
                if let newProtein = nutrition.protein {
                    accumulated.protein = newProtein
                    self.proteinText = String(format: "%.1f", newProtein)
                }
                if let newFat = nutrition.fat {
                    accumulated.fat = newFat
                    self.fatText = String(format: "%.1f", newFat)
                }
                if let newFiber = nutrition.fiber {
                    accumulated.fiber = newFiber
                    self.fiberText = String(format: "%.1f", newFiber)
                }
                if let newMoisture = nutrition.moisture {
                    accumulated.moisture = newMoisture
                    self.moistureText = String(format: "%.1f", newMoisture)
                }
                if let newAsh = nutrition.ash {
                    accumulated.ash = newAsh
                    self.ashText = String(format: "%.1f", newAsh)
                }

                self.detectedNutrition = accumulated

                // Update OCR text for debugging (show last 10 lines)
                self.lastOCRText = Array(texts.suffix(10))

                // Stop scanning if all values are detected
                if accumulated.protein != nil &&
                   accumulated.fat != nil &&
                   accumulated.fiber != nil &&
                   accumulated.moisture != nil &&
                   accumulated.ash != nil {
                    self.stopContinuousScanning()
                }
            }
        } catch {
            print("OCR error: \(error)")
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }

    private func validateBarcodeCheckDigit(_ barcode: String) -> Bool {
        let digits = barcode.compactMap { $0.wholeNumberValue }
        guard digits.count == barcode.count else { return false }

        // Support EAN-8, UPC-A (12), and EAN-13
        guard [8, 12, 13].contains(digits.count) else { return false }

        // Calculate check digit: alternate multiplying by 1 and 3
        var sum = 0
        for i in 0..<(digits.count - 1) {
            let multiplier = (i % 2 == 0) ? 1 : 3
            sum += digits[i] * multiplier
        }

        let calculatedCheckDigit = (10 - (sum % 10)) % 10
        let actualCheckDigit = digits[digits.count - 1]

        return calculatedCheckDigit == actualCheckDigit
    }

    private func extractBarcodeFromText(_ texts: [String]) -> String? {
        print("🔍 Trying to extract barcode from OCR text...")

        var candidates: [String] = []

        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespaces)

            // Pattern 1: Standard EAN-13 format: 1 digit + 6 digits + 6 digits
            // Example: "4 017721 837194" or "4017721837194"
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

            // Pattern 2: 12-digit fallback (OCR often misses leading digit)
            // Try prepending different digits, prefer European prefixes (4, 0-3, 5-9)
            let digitsOnly = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if digitsOnly.count == 12 {
                // Try prefixes in priority order: 4 (Germany/Europe), then others
                let prefixPriority = [4, 0, 1, 2, 3, 5, 6, 7, 8, 9]
                for prefix in prefixPriority {
                    let barcode = "\(prefix)" + digitsOnly
                    if validateBarcodeCheckDigit(barcode) && !candidates.contains(barcode) {
                        candidates.append(barcode)
                        print("   Found valid barcode (reconstructed with prefix \(prefix)): \(barcode) ✓")
                        break  // Stop after finding first valid combination in priority order
                    }
                }
            }
        }

        if !candidates.isEmpty {
            // Prefer European barcodes (starting with 4) over others
            let preferredBarcode = candidates.first { $0.hasPrefix("4") } ?? candidates.first!
            print("✅ Selected barcode: \(preferredBarcode)")
            return preferredBarcode
        }

        print("⚠️ No valid barcode found in OCR text")
        return nil
    }

    private func detectBarcode(in cgImage: CGImage) {
        print("🔍 detectBarcode called")
        print("🔍 Image size: \(cgImage.width)x\(cgImage.height)")

        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("❌ Barcode detection error: \(error)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation] else {
                print("⚠️ No barcode results (wrong type)")
                return
            }

            print("🔍 Barcode detection returned \(results.count) result(s)")

            if results.isEmpty {
                print("⚠️ No barcodes found in image")
                print("💡 Tip: Make sure barcode is clear, well-lit, and not too small")
                return
            }

            for (index, barcode) in results.enumerated() {
                print("🔍 Barcode #\(index + 1): symbology=\(barcode.symbology.rawValue), confidence=\(barcode.confidence)")
                if let payload = barcode.payloadStringValue {
                    print("   Payload: \(payload)")
                } else {
                    print("   Payload: nil")
                }
            }

            guard let firstBarcode = results.first,
                  let payloadString = firstBarcode.payloadStringValue else {
                print("⚠️ Could not get barcode payload from first result")
                return
            }

            print("✅ Detected barcode: \(payloadString)")

            DispatchQueue.main.async {
                // Only process if this is a new barcode
                guard self.detectedBarcode != payloadString else {
                    print("ℹ️ Barcode already detected")
                    return
                }

                self.detectedBarcode = payloadString
                print("🔍 Checking database for barcode...")

                // Check if product exists in database
                self.checkDatabaseForBarcode(payloadString)
            }
        }

        request.symbologies = [.upce, .ean8, .ean13, .code128, .code39, .code93, .i2of5, .itf14, .pdf417, .qr, .aztec]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("❌ Error performing barcode detection: \(error)")
        }
    }

    private func checkDatabaseForBarcode(_ barcode: String) {
        // Query Open Pet Food Facts API directly
        Task {
            await queryOpenPetFoodFacts(barcode: barcode)
        }
    }

    private func queryOpenPetFoodFacts(barcode: String) async {
        print("Querying Open Pet Food Facts for barcode: \(barcode)")

        await MainActor.run {
            isLoadingFromAPI = true
            apiStatusMessage = "Searching database..."
        }

        let service = OpenPetFoodFactsService()

        do {
            if var product = try await service.fetchProduct(barcode: barcode) {
                print("Found product in Open Pet Food Facts: \(product.productName)")

                // Merge with OCR data - prefer OCR when database has suspicious or missing data
                await MainActor.run {
                    if let ocrNutrition = self.detectedNutrition {
                        var needsMerge = false

                        // Use OCR protein if database is 0, too low (<3%), or OCR is significantly higher
                        if let ocrProtein = ocrNutrition.protein, ocrProtein > 0 {
                            if product.protein == 0 || product.protein < 3.0 || ocrProtein > product.protein * 2 {
                                print("📝 Using OCR protein: \(ocrProtein)% (was: \(product.protein)%)")
                                product.protein = ocrProtein
                                needsMerge = true
                            }
                        }

                        // Use OCR fat if database is 0, too low (<1%), or OCR is significantly higher
                        if let ocrFat = ocrNutrition.fat, ocrFat > 0 {
                            if product.fat == 0 || product.fat < 1.0 || ocrFat > product.fat * 2 {
                                print("📝 Using OCR fat: \(ocrFat)% (was: \(product.fat)%)")
                                product.fat = ocrFat
                                needsMerge = true
                            }
                        }

                        // Use OCR fiber if database is 0 or OCR has data
                        if product.fiber == 0, let ocrFiber = ocrNutrition.fiber, ocrFiber > 0 {
                            print("📝 Using OCR fiber: \(ocrFiber)%")
                            product.fiber = ocrFiber
                            needsMerge = true
                        }

                        // Use OCR ash if database is 0 or OCR has data
                        if product.ash == 0, let ocrAsh = ocrNutrition.ash, ocrAsh > 0 {
                            print("📝 Using OCR ash: \(ocrAsh)%")
                            product.ash = ocrAsh
                            needsMerge = true
                        }

                        // Use OCR moisture if database is 0 or suspiciously low
                        if let ocrMoisture = ocrNutrition.moisture, ocrMoisture > 0 {
                            if product.moisture == 0 || (ocrMoisture > 50 && product.moisture < 50) {
                                if product.moisture != ocrMoisture {
                                    print("📝 Using OCR moisture: \(ocrMoisture)% (was: \(product.moisture)%)")
                                    product.moisture = ocrMoisture
                                    needsMerge = true
                                }
                            }
                        }

                        if needsMerge {
                            print("✅ Merged database and OCR nutrition data")
                        }
                    }

                    isLoadingFromAPI = false
                    apiStatusMessage = ""
                    stopContinuousScanning()
                    existingProduct = product
                    showProductDetail = true
                }
            } else {
                print("Product not found in Open Pet Food Facts")
                await MainActor.run {
                    isLoadingFromAPI = false
                    apiStatusMessage = "Not found in database. Scan nutrition label or enter manually."
                }
                // Continue scanning to let user enter data manually
            }
        } catch {
            print("Open Pet Food Facts API error: \(error)")
            await MainActor.run {
                isLoadingFromAPI = false
                apiStatusMessage = "API error: \(error.localizedDescription)"
            }
            // Continue scanning to let user enter data manually
        }
    }
}

// MARK: - Camera Model
class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    private var output = AVCapturePhotoOutput()
    private var photoCompletion: ((UIImage) -> Void)?

    func startSession() {
        // If session is already running, just continue
        if session.isRunning {
            print("Camera session already running")
            return
        }

        // Setup session if needed
        if session.inputs.isEmpty {
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                print("Failed to get camera device or input")
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                print("Cannot add input to session")
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                print("Cannot add output to session")
            }
        }

        print("Starting camera session...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            print("Camera session started: \(self.session.isRunning)")
        }
    }

    func stopSession() {
        if session.isRunning {
            print("Stopping camera session...")
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
                print("Camera session stopped")
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        guard session.isRunning else {
            print("ERROR: Cannot capture photo - session not running")
            return
        }

        print("Capturing photo...")
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
        if let error = error {
            print("Photo capture error: \(error)")
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("Failed to get image data from photo")
            return
        }

        print("Photo captured successfully, calling completion")
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
