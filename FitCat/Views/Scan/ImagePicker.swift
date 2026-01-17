//
//  ImagePicker.swift
//  FitCat
//
//  Photo picker for simulator testing
//

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var images: [UIImage]?
    var allowMultiple: Bool
    @Environment(\.dismiss) private var dismiss

    init(image: Binding<UIImage?>) {
        self._image = image
        self._images = .constant(nil)
        self.allowMultiple = false
    }

    init(images: Binding<[UIImage]?>) {
        self._image = .constant(nil)
        self._images = images
        self.allowMultiple = true
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = allowMultiple ? 0 : 1 // 0 = unlimited

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            if parent.allowMultiple {
                // Load multiple images
                var loadedImages: [UIImage] = []
                let group = DispatchGroup()

                for result in results {
                    guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }

                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                        if let image = image as? UIImage {
                            loadedImages.append(image)
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.parent.images = loadedImages
                }
            } else {
                // Load single image
                guard let provider = results.first?.itemProvider else { return }

                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, error in
                        DispatchQueue.main.async {
                            self.parent.image = image as? UIImage
                        }
                    }
                }
            }
        }
    }
}
