import SwiftUI
import UIKit

/// Wraps `UIImagePickerController` for both camera and photo-library selection.
/// `allowsEditing = true` enables Apple's built-in square crop UI after capture/selection.
struct ImagePicker: UIViewControllerRepresentable {
    enum Source: Identifiable {
        case camera
        case library

        var id: Self { self }

        var uiKitSource: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .library: return .photoLibrary
            }
        }
    }

    let source: Source
    var onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Fall back to library if the camera isn't available (e.g. simulator).
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(source.uiKitSource)
            ? source.uiKitSource
            : .photoLibrary
        picker.allowsEditing = true // Built-in crop UI.
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Prefer the cropped image, fall back to the original.
            if let edited = info[.editedImage] as? UIImage {
                parent.onPicked(edited)
            } else if let original = info[.originalImage] as? UIImage {
                parent.onPicked(original)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
