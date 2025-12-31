import Foundation

final class StrategyEngine {
    func advise(for state: GameState) -> Advice {
        guard let turn = state.turn, let gold = state.gold else {
            return .empty
        }

        var details: [String] = []
        let health = state.health ?? 40
        let tier = state.tavernTier ?? 1

        if health <= 15 {
            details.append("血量偏低，优先保血与即时战力。")
        } else if health >= 30 {
            details.append("血量充裕，可考虑更激进的升本节奏。")
        }

        if shouldLevelUp(turn: turn, gold: gold, tier: tier, health: health) {
            details.append("建议升本，争取更强商店质量。")
        } else if gold <= 3 {
            details.append("金币较少，优先补充战力或锁店。")
        } else {
            details.append("可视商店质量进行搜卡。")
        }

        let headline = "第\(turn)回合 · \(gold)金 · \(health)血 · T\(tier)"
        return Advice(headline: headline, details: details)
    }

    private func shouldLevelUp(turn: Int, gold: Int, tier: Int, health: Int) -> Bool {
        if health <= 12 { return false }
        if tier >= 6 { return false }
        if turn <= 2 { return false }

        // Very rough heuristic for MVP stage.
        let goldToLevel = max(0, 10 - tier * 2)
        return gold >= goldToLevel
    }
}
