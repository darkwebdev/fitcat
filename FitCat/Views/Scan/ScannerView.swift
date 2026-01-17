//
//  ScannerView.swift
//  FitCat
//
//  Main scanner view with barcode and OCR modes
//

import SwiftUI
import AVFoundation

struct ScannerView: View {
    @Binding var resetTrigger: Int

    @State private var scanMode: ScanMode = .barcode
    @State private var showingProductForm = false
    @State private var showingProductDetail = false
    @State private var selectedProduct: Product?
    @State private var scannedNutrition: NutritionInfo?
    @State private var scannedBarcode: String?
    @State private var cameraPermissionGranted = false
    @State private var showingPermissionAlert = false

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var databaseManager: DatabaseManager

    enum ScanMode {
        case barcode
        case ocr
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Scanner view
                if cameraPermissionGranted {
                    OCRScannerView(resetTrigger: $resetTrigger) { nutrition in
                        handleOCRScan(nutrition)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    permissionDeniedView
                }
            }
            .navigationTitle("Scan Product")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkCameraPermission()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    checkCameraPermission()
                }
            }
            .sheet(isPresented: $showingProductForm) {
                if let nutrition = scannedNutrition {
                    ProductFormView(prefillData: nutrition)
                } else {
                    ProductFormView()
                }
            }
            .sheet(isPresented: $showingProductDetail) {
                if let product = selectedProduct {
                    NavigationView {
                        ProductDetailView(product: product)
                    }
                }
            }
            .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("FitCat needs camera access to scan barcodes and nutrition labels. Please enable it in Settings.")
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please enable camera access in Settings to scan products")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.cameraPermissionGranted = true
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.cameraPermissionGranted = granted
                    if !granted {
                        self.showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.cameraPermissionGranted = false
                // Only show alert once
                if !self.showingPermissionAlert {
                    self.showingPermissionAlert = true
                }
            }
        @unknown default:
            DispatchQueue.main.async {
                self.cameraPermissionGranted = false
            }
        }
    }

    private func handleBarcodeDetection(_ barcode: String) {
        scannedBarcode = barcode

        // Look up in database
        do {
            if let product = try databaseManager.findByBarcode(barcode) {
                // Product found - show details
                selectedProduct = product
                showingProductDetail = true
            } else {
                // Product not found - switch to OCR mode or show form
                scanMode = .ocr
            }
        } catch {
            print("Database error: \(error)")
            scanMode = .ocr
        }
    }

    private func handleOCRScan(_ nutrition: NutritionInfo) {
        scannedNutrition = nutrition
        showingProductForm = true
    }
}

#Preview {
    ScannerView(resetTrigger: .constant(0))
        .environmentObject(DatabaseManager.shared)
}
