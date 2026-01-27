//
//  OCRService.swift
//  FitCat
//
//  Text recognition service using Vision framework
//

import Vision
import UIKit

class OCRService {
    private var lastOCRTime: Date?

    /// Recognizes text from an image
    /// - Parameter image: CGImage to process
    /// - Returns: Array of recognized text with confidence scores
    func recognizeText(from image: CGImage) async throws -> [VNRecognizedText] {
        #if targetEnvironment(simulator)
        // WORKAROUND: Throttle OCR to prevent Vision framework crash in simulator
        // Vision crashes when processing multiple images too quickly
        if let lastTime = lastOCRTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < 1.5 {
                let delay = 1.5 - elapsed
                NSLog("🔴 FITCAT: Throttling OCR, waiting \(delay)s")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        lastOCRTime = Date()
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let recognizedTexts = observations.compactMap { observation in
                    observation.topCandidates(1).first
                }

                continuation.resume(returning: recognizedTexts)
            }

            // Use accurate recognition level for better results
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    /// Recognizes text from a UIImage
    /// - Parameter image: UIImage to process
    /// - Returns: Array of recognized text strings
    func recognizeText(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let texts = try await recognizeText(from: cgImage)
        return texts.map { $0.string }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextDetected

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextDetected:
            return "No text was detected in the image"
        }
    }
}
