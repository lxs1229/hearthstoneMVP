import Foundation

struct GameState: Equatable {
    var timestamp: Date
    var turn: Int?
    var gold: Int?
    var health: Int?
    var tavernTier: Int?
    var phase: GamePhase?
    var step: String?
    var mode: GameMode?
}

extension GameState {
    static let empty = GameState(
        timestamp: Date(),
        turn: nil,
        gold: nil,
        health: nil,
        tavernTier: nil,
        phase: nil,
        step: nil,
        mode: nil
    )

    mutating func merge(_ partial: PartialGameState) {
        timestamp = partial.timestamp ?? timestamp
        turn = partial.turn ?? turn
        gold = partial.gold ?? gold
        health = partial.health ?? health
        tavernTier = partial.tavernTier ?? tavernTier
        phase = partial.phase ?? phase
        step = partial.step ?? step
        mode = partial.mode ?? mode
    }
}

struct PartialGameState {
    var timestamp: Date?
    var turn: Int?
    var gold: Int?
    var health: Int?
    var tavernTier: Int?
    var phase: GamePhase?
    var step: String?
    var mode: GameMode?
}

enum GamePhase: String, Equatable {
    case shopping
    case combat
    case unknown
}

enum GameMode: String, Equatable {
    case battlegrounds
    case other
    case unknown

    var displayName: String {
        switch self {
        case .battlegrounds:
            return "酒馆战棋"
        case .other:
            return "其他模式"
        case .unknown:
            return "未识别"
        }
    }
}
