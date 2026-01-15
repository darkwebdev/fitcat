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

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var databaseManager: DatabaseManager

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

    var body: some View {
        GeometryReader { geometry in
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
                    // Camera preview
                    CameraPreview(camera: cameraModel)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 1.1).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height * 0.5)

            // Bottom form - scrollable
            ScrollView {
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

                        if detectedBarcode != nil {
                            HStack {
                                Text("Barcode")
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 100, alignment: .leading)

                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text(detectedBarcode!)
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .font(.subheadline)
                        }

                        textInputRow("Product Name", $productName)
                        textInputRow("Brand", $brand)
                    }

                    // Add to Database button
                    if allValuesDetected {
                        Button {
                            saveToDatabase()
                        } label: {
                            Text("Add to Database")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isFormValid ? Color.green : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!isFormValid)
                        .padding(.top, 12)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.8))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: allValuesDetected)
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            cameraModel.startSession()
            startContinuousScanning()
        }
        .onDisappear {
            cameraModel.stopSession()
            stopContinuousScanning()
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

    private func saveToDatabase() {
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

        do {
            try databaseManager.insert(product)
            dismiss()
        } catch {
            errorMessage = "Failed to save product: \(error.localizedDescription)"
            showError = true
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

        // Then scan every 1.5 seconds
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
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

    private func processImage(_ image: UIImage) async {
        let ocrService = OCRService()
        let parser = NutritionParser()

        // Detect barcode
        if let cgImage = image.cgImage {
            detectBarcode(in: cgImage)
        }

        do {
            let texts = try await ocrService.recognizeText(from: image)
            print("OCR detected \(texts.count) text lines")
            let nutrition = parser.parseNutrition(from: texts)
            print("Parsed nutrition: p=\(nutrition.protein?.description ?? "nil"), f=\(nutrition.fat?.description ?? "nil"), fi=\(nutrition.fiber?.description ?? "nil"), m=\(nutrition.moisture?.description ?? "nil"), a=\(nutrition.ash?.description ?? "nil")")

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

    private func detectBarcode(in cgImage: CGImage) {
        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                print("Barcode detection error: \(error)")
                return
            }

            guard let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first,
                  let payloadString = firstBarcode.payloadStringValue else {
                return
            }

            DispatchQueue.main.async {
                self.detectedBarcode = payloadString
            }
        }

        request.symbologies = [.upce, .ean8, .ean13, .code128, .code39, .code93]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - Camera Model
class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    private var output = AVCapturePhotoOutput()
    private var photoCompletion: ((UIImage) -> Void)?

    func startSession() {
        guard session.inputs.isEmpty else {
            print("Camera session already has inputs")
            return
        }

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

        print("Starting camera session...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            print("Camera session started: \(self.session.isRunning)")
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
