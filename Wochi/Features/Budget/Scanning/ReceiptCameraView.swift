import SwiftUI
import UIKit

// MARK: - ReceiptCameraView

struct ReceiptCameraView: View {
    @Environment(\.dismiss) private var dismiss
    /// Injected via environment or direct init so previews can stub it.
    let scanUseCase: ScanReceiptUseCase
    let household: Household

    @State private var pickerSource: UIImagePickerController.SourceType = .camera
    @State private var showPicker = false
    @State private var flashOn = false
    @State private var isScanning = false
    @State private var scannedReceipt: Receipt?
    @State private var showReview = false
    @State private var scanError: WochiError?
    @State private var showErrorAlert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera picker fills the background
            if showPicker {
                ImagePickerRepresentable(
                    sourceType: pickerSource,
                    flashMode: flashOn ? .on : .off,
                    onImagePicked: { image in
                        showPicker = false
                        Task { await handlePicked(image: image) }
                    },
                    onCancel: { showPicker = false }
                )
                .ignoresSafeArea()
            }

            // Receipt-frame guide overlay
            ReceiptGuideOverlay()

            // Controls overlay
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button {
                        flashOn.toggle()
                    } label: {
                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2.bold())
                            .foregroundStyle(flashOn ? Color.yellow : Color.white)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        pickerSource = .camera
                        showPicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 58, height: 58)
                        }
                    }
                    .disabled(isScanning)

                    Button {
                        pickerSource = .photoLibrary
                        showPicker = true
                    } label: {
                        Text("Aus Fotos wählen")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .disabled(isScanning)
                }
                .padding(.bottom, 48)
            }

            // Loading overlay
            if isScanning {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                    Text("Bon wird erkannt…")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
        }
        .fullScreenCover(isPresented: $showReview) {
            if let receipt = scannedReceipt {
                ReceiptReviewView(
                    receipt: receipt,
                    scanUseCase: scanUseCase,
                    household: household,
                    onDismiss: { dismiss() }
                )
            }
        }
        .alert(
            "Fehler beim Scannen",
            isPresented: $showErrorAlert,
            presenting: scanError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .onAppear {
            pickerSource = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
            showPicker = true
        }
    }

    private func handlePicked(image: UIImage) async {
        isScanning = true
        defer { isScanning = false }
        do {
            let receipt = try await scanUseCase.scanImage(image)
            scannedReceipt = receipt
            showReview = true
        } catch let wochiErr as WochiError {
            scanError = wochiErr
            showErrorAlert = true
        } catch {
            scanError = .receiptParsingFailed
            showErrorAlert = true
        }
    }
}

// MARK: - ReceiptGuideOverlay

private struct ReceiptGuideOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.82
            let height = geo.size.height * 0.60
            let x = (geo.size.width - width) / 2
            let y = (geo.size.height - height) / 2.2

            ZStack {
                // Dimmed surround
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(width: width, height: height)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                // Corner marks
                let cornerLength: CGFloat = 24
                let lineWidth: CGFloat = 3

                Group {
                    // Top-left
                    CornerMark(rotation: 0)
                        .position(x: x, y: y)
                    // Top-right
                    CornerMark(rotation: 90)
                        .position(x: x + width, y: y)
                    // Bottom-right
                    CornerMark(rotation: 180)
                        .position(x: x + width, y: y + height)
                    // Bottom-left
                    CornerMark(rotation: 270)
                        .position(x: x, y: y + height)
                }
                .frame(width: cornerLength, height: cornerLength)
                .foregroundStyle(.white)

                Text("Kassenbon ausrichten")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .position(x: geo.size.width / 2, y: y + height + 20)

                // Suppress unused variable warnings
                let _ = lineWidth
            }
        }
    }
}

// MARK: - CornerMark

private struct CornerMark: View {
    let rotation: Double

    var body: some View {
        Path { path in
            let len: CGFloat = 24
            path.move(to: CGPoint(x: 0, y: len))
            path.addLine(to: .zero)
            path.addLine(to: CGPoint(x: len, y: 0))
        }
        .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(rotation))
        .frame(width: 24, height: 24)
    }
}

// MARK: - ImagePickerRepresentable

private struct ImagePickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let flashMode: UIImagePickerController.CameraFlashMode
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        if picker.sourceType == .camera {
            picker.cameraFlashMode = flashMode
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        if uiViewController.sourceType == .camera {
            uiViewController.cameraFlashMode = flashMode
        }
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImagePicked = onImagePicked
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

// MARK: - Preview

#Preview {
    // Show the guide overlay on a gray background — no live camera in previews
    ZStack {
        Color.gray.ignoresSafeArea()
        ReceiptGuideOverlay()
    }
}
