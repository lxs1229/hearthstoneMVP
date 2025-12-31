import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreImage

final class CaptureManager: NSObject {
    private let config: CaptureConfig
    private let ocr = OCRProcessor()
    private let ciContext = CIContext()
    private let captureQueue = DispatchQueue(label: "hs.capture.queue")
    private let ocrQueue = DispatchQueue(label: "hs.ocr.queue")
    private var stream: SCStream?
    private var lastOCR = Date.distantPast
    private var lastPreview = Date.distantPast
    private let previewInterval: TimeInterval = 0.6

    var onStateUpdate: ((PartialGameState) -> Void)?
    var onError: ((String) -> Void)?
    var onPreviewImage: ((CGImage) -> Void)?
    var previewEnabled = false

    init(config: CaptureConfig) {
        self.config = config
    }

    func start() async throws {
        if stream != nil { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let targetWindow = findTargetWindow(in: content.windows)
        let filter: SCContentFilter
        let captureSize: CGSize

        if let targetWindow {
            filter = SCContentFilter(desktopIndependentWindow: targetWindow)
            captureSize = targetWindow.frame.size
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
            captureSize = CGSize(width: display.width, height: display.height)
        }

        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(captureSize.width))
        configuration.height = max(1, Int(captureSize.height))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(config.framesPerSecond))
        configuration.queueDepth = 2

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        let now = Date()
        let shouldOCR = now.timeIntervalSince(lastOCR) >= config.ocrInterval
        let shouldPreview = previewEnabled && now.timeIntervalSince(lastPreview) >= previewInterval
        if !shouldOCR && !shouldPreview { return }

        guard let cgImage = makeCGImage(from: imageBuffer) else { return }

        if shouldPreview {
            lastPreview = now
            DispatchQueue.main.async { [weak self] in
                self?.onPreviewImage?(cgImage)
            }
        }

        guard shouldOCR else { return }
        lastOCR = now

        ocrQueue.async { [weak self] in
            guard let self else { return }
            var partial = PartialGameState(timestamp: Date(), turn: nil, gold: nil, health: nil, tavernTier: nil)

            for region in self.config.regions {
                guard let crop = self.crop(image: cgImage, normalizedRect: region.normalizedRect) else { continue }
                guard let text = self.ocr.recognizeDigits(in: crop) else { continue }
                let value = Int(text)

                switch region.kind {
                case .turn:
                    partial.turn = value
                case .gold:
                    partial.gold = value
                case .health:
                    partial.health = value
                case .tavernTier:
                    partial.tavernTier = value
                }
            }

            if partial.turn != nil || partial.gold != nil || partial.health != nil || partial.tavernTier != nil {
                DispatchQueue.main.async {
                    self.onStateUpdate?(partial)
                }
            }
        }
    }

    private func makeCGImage(from imageBuffer: CVImageBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    private func crop(image: CGImage, normalizedRect: CGRect) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        let rect = CGRect(
            x: normalizedRect.origin.x * width,
            y: (1.0 - normalizedRect.origin.y - normalizedRect.height) * height,
            width: normalizedRect.size.width * width,
            height: normalizedRect.size.height * height
        ).integral

        guard rect.width > 1, rect.height > 1 else { return nil }
        return image.cropping(to: rect)
    }

    private func findTargetWindow(in windows: [SCWindow]) -> SCWindow? {
        let keywords = config.windowTitleKeywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !keywords.isEmpty else { return nil }

        return windows.first { window in
            let title = (window.title ?? "").lowercased()
            return keywords.contains { title.contains($0) }
        }
    }
}

extension CaptureManager: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        processFrame(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onError?("捕获停止：\(error.localizedDescription)")
    }
}

enum CaptureError: Error {
    case noDisplay
}
