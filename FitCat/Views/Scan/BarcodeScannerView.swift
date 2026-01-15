//
//  BarcodeScannerView.swift
//  FitCat
//
//  SwiftUI wrapper for barcode scanner
//

import SwiftUI
import UIKit

struct BarcodeScannerView: UIViewRepresentable {
    let onBarcodeDetected: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let scanner = BarcodeScanner()
        context.coordinator.scanner = scanner

        // Setup camera asynchronously
        DispatchQueue.main.async {
            scanner.setupCamera(in: view) { barcode in
                self.onBarcodeDetected(barcode)
            }
        }

        // Add overlay guide
        let overlay = createOverlay()
        view.addSubview(overlay)

        // Constrain overlay to fill view
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update view if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func createOverlay() -> UIView {
        let overlay = UIView()
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false

        // Scanning rectangle
        let scanRect = UIView()
        scanRect.layer.borderColor = UIColor.systemGreen.cgColor
        scanRect.layer.borderWidth = 2
        scanRect.layer.cornerRadius = 12
        scanRect.backgroundColor = .clear
        scanRect.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(scanRect)

        // Label
        let label = UILabel()
        label.text = "Align barcode within frame"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(label)

        NSLayoutConstraint.activate([
            scanRect.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            scanRect.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            scanRect.widthAnchor.constraint(equalToConstant: 280),
            scanRect.heightAnchor.constraint(equalToConstant: 180),

            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.topAnchor.constraint(equalTo: scanRect.bottomAnchor, constant: 24)
        ])

        return overlay
    }

    class Coordinator {
        var scanner: BarcodeScanner?
    }
}
