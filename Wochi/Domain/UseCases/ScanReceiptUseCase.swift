import Foundation
import Vision
import UIKit

@MainActor
final class ScanReceiptUseCase {
    private let repository: ReceiptRepositoryProtocol

    init(repository: ReceiptRepositoryProtocol) {
        self.repository = repository
    }

    func scanImage(_ image: UIImage) async throws -> Receipt {
        guard let cgImage = image.cgImage else {
            throw WochiError.receiptParsingFailed
        }

        let text = try await recognizeText(in: cgImage)
        guard !text.isEmpty else {
            throw WochiError.receiptParsingFailed
        }

        let receipt = ReceiptParser.parse(text: text)
        receipt.rawOCRText = text
        return receipt
    }

    private func recognizeText(in cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func save(_ receipt: Receipt, for household: Household) async throws {
        try await repository.saveReceipt(receipt, for: household)
    }
}
