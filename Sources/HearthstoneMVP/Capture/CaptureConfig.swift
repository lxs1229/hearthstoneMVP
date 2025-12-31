import Foundation
import CoreGraphics

enum OCRFieldKind {
    case turn
    case gold
    case health
    case tavernTier
}

struct CaptureRegion {
    let name: String
    let kind: OCRFieldKind
    let normalizedRect: CGRect
}

struct CaptureConfig {
    let regions: [CaptureRegion]
    let ocrInterval: TimeInterval
    let framesPerSecond: Int
    let windowTitleKeywords: [String]

    static let defaultConfig = CaptureConfig(
        regions: [
            // TODO: 根据实际UI位置调整这些区域（归一化坐标，左上为(0,0)）。
            CaptureRegion(name: "Turn", kind: .turn, normalizedRect: CGRect(x: 0.48, y: 0.02, width: 0.05, height: 0.03)),
            CaptureRegion(name: "Gold", kind: .gold, normalizedRect: CGRect(x: 0.46, y: 0.86, width: 0.08, height: 0.05)),
            CaptureRegion(name: "Health", kind: .health, normalizedRect: CGRect(x: 0.02, y: 0.88, width: 0.06, height: 0.05)),
            CaptureRegion(name: "Tier", kind: .tavernTier, normalizedRect: CGRect(x: 0.46, y: 0.78, width: 0.05, height: 0.05))
        ],
        ocrInterval: 0.8,
        framesPerSecond: 4,
        windowTitleKeywords: ["Hearthstone", "炉石传说"]
    )
}
