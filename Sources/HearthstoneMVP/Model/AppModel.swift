import Foundation
import CoreGraphics

@MainActor
final class AppModel: ObservableObject {
    @Published var state: GameState = .empty
    @Published var advice: Advice = .empty
    @Published var isCapturing = false
    @Published var lastError: String?
    @Published var previewImage: CGImage?
    @Published var usePowerLog = true {
        didSet {
            if usePowerLog {
                showPreview = false
            }
            if isCapturing {
                stopCapture(usingPowerLog: oldValue)
                startCapture()
            }
        }
    }
    @Published var powerLogPath: String?
    @Published var localPlayerName: String?
    @Published var lastUpdate: Date?
    @Published var showPreview = false {
        didSet {
            if usePowerLog && showPreview {
                showPreview = false
                return
            }
            captureManager.previewEnabled = showPreview
            if !showPreview {
                previewImage = nil
            }
        }
    }

    private let captureManager: CaptureManager
    private let logMonitor = UnifiedLogMonitor()
    private let engine = StrategyEngine()
    let config: CaptureConfig

    init(config: CaptureConfig = .defaultConfig) {
        self.config = config
        captureManager = CaptureManager(config: config)
        logMonitor.onStateUpdate = { [weak self] partial in
            guard let self else { return }
            self.state.merge(partial)
            self.advice = self.engine.advise(for: self.state)
            self.lastUpdate = Date()
        }
        logMonitor.onLogPathResolved = { [weak self] path in
            self?.powerLogPath = path
        }
        logMonitor.onLocalPlayerResolved = { [weak self] _, name in
            self?.localPlayerName = name
        }
        logMonitor.onError = { [weak self] message in
            self?.lastError = message
        }
        captureManager.onStateUpdate = { [weak self] partial in
            guard let self else { return }
            self.state.merge(partial)
            self.advice = self.engine.advise(for: self.state)
        }
        captureManager.onPreviewImage = { [weak self] image in
            guard let self, self.showPreview else { return }
            self.previewImage = image
        }
        captureManager.onError = { [weak self] message in
            self?.lastError = message
        }
    }

    func startCapture() {
        lastError = nil
        if usePowerLog {
            isCapturing = logMonitor.start()
        } else {
            Task {
                do {
                    try await captureManager.start()
                    isCapturing = true
                } catch {
                    lastError = "启动捕获失败：\(error.localizedDescription)"
                    isCapturing = false
                }
            }
        }
    }

    func stopCapture() {
        stopCapture(usingPowerLog: usePowerLog)
    }

    private func stopCapture(usingPowerLog: Bool) {
        if usingPowerLog {
            logMonitor.stop()
            isCapturing = false
        } else {
            Task {
                await captureManager.stop()
                isCapturing = false
            }
        }
    }

    func requestScreenRecordingAccess() {
        _ = CGRequestScreenCaptureAccess()
    }
}
