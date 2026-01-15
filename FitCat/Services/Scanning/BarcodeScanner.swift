//
//  BarcodeScanner.swift
//  FitCat
//
//  Barcode detection using Vision framework
//

import AVFoundation
import Vision
import UIKit

class BarcodeScanner: NSObject, ObservableObject {
    @Published var detectedBarcode: String?
    @Published var isScanning = false

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var onBarcodeDetected: ((String) -> Void)?

    func setupCamera(in view: UIView, completion: @escaping (String) -> Void) {
        self.onBarcodeDetected = completion

        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            print("Failed to create capture session")
            return
        }

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("No video capture device available")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Error creating video input: \(error)")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Cannot add video input to session")
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "barcode"))

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Cannot add video output to session")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill

        if let previewLayer = previewLayer {
            // Insert at index 0 to be behind any overlays
            view.layer.insertSublayer(previewLayer, at: 0)

            // Set frame after adding to layer
            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
            }
        }

        print("Starting camera session...")
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
            DispatchQueue.main.async {
                self.isScanning = true
                print("Camera session started, isScanning: \(self.isScanning)")
            }
        }
    }

    func startScanning() {
        guard let captureSession = captureSession else { return }
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isScanning = true
                }
            }
        }
    }

    func stopScanning() {
        guard let captureSession = captureSession else { return }
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isScanning = false
                }
            }
        }
    }

    private func detectBarcode(in image: CVPixelBuffer) {
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
                self.stopScanning()
                self.onBarcodeDetected?(payloadString)

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }

        // Support multiple barcode types
        request.symbologies = [.upce, .ean8, .ean13, .code128, .code39, .code93]

        let handler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
        try? handler.perform([request])
    }
}

extension BarcodeScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isScanning,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        detectBarcode(in: pixelBuffer)
    }
}
