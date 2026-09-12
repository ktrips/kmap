import Photos
import SwiftUI
import UIKit

/// `UIImagePickerController`（カメラ）をSwiftUIから使うためのラッパー。
/// `PhotosPicker`はライブラリからの選択しかできないため、その場で撮影したい時に使う。
/// 撮影した写真は、アプリ内での加工（フィルター等）を適用する前の状態で
/// iPhoneの写真ライブラリにもそのまま保存する（カメラアプリで撮った時と同じ体験にするため）。
struct CameraCaptureView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                saveToPhotoLibrary(image)
                onCapture(image)
            } else {
                onCancel()
            }
        }

        /// 撮った写真をiPhoneの写真ライブラリにも保存する。追加のみの権限
        /// （`NSPhotoLibraryAddUsageDescription`）で行えるため、保存の可否を
        /// 待たせずその場で試み、権限が無ければ静かに諦める
        /// （ライブラリへの保存はおまけの機能で、アプリ内保存の方は別途行われるため）。
        private func saveToPhotoLibrary(_ image: UIImage) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else { return }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
