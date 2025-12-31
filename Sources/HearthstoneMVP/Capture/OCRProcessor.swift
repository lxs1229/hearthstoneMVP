import Foundation
import Vision

final class OCRProcessor {
    private let request: VNRecognizeTextRequest

    init() {
        request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.02
    }

    func recognizeDigits(in image: CGImage) -> String? {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return nil
        }

        let candidates = observations.compactMap { $0.topCandidates(1).first?.string }
        let raw = candidates.joined(separator: " ")
        let digits = raw.filter { $0.isNumber }
        return digits.isEmpty ? nil : digits
    }
}
