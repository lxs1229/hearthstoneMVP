import Foundation

struct GameState: Equatable {
    var timestamp: Date
    var turn: Int?
    var gold: Int?
    var health: Int?
    var tavernTier: Int?
    var phase: GamePhase?
    var step: String?
}

extension GameState {
    static let empty = GameState(timestamp: Date(), turn: nil, gold: nil, health: nil, tavernTier: nil, phase: nil, step: nil)

    mutating func merge(_ partial: PartialGameState) {
        timestamp = partial.timestamp ?? timestamp
        turn = partial.turn ?? turn
        gold = partial.gold ?? gold
        health = partial.health ?? health
        tavernTier = partial.tavernTier ?? tavernTier
        phase = partial.phase ?? phase
        step = partial.step ?? step
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
}

enum GamePhase: String, Equatable {
    case shopping
    case combat
    case unknown
}
