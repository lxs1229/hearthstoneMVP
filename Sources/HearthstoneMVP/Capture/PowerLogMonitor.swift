import Foundation

final class PowerLogMonitor {
    private let queue = DispatchQueue(label: "hs.powerlog.queue")
    private let logURL: URL
    private var fileHandle: FileHandle?
    private var buffer = Data()
    private var localPlayerId: Int?
    private var lastTagValues: [String: Int] = [:]
    private var resourcesByPlayer: [Int: PlayerResources] = [:]
    private var playerNameToId: [String: Int] = [:]

    private let tagValueRegex = try? NSRegularExpression(
        pattern: "tag=([A-Z0-9_]+)\\s+value=([^\\s]+)",
        options: []
    )
    private let entityPlayerRegex = try? NSRegularExpression(
        pattern: "Entity=Player#(\\d+)",
        options: []
    )
    private let inlinePlayerRegex = try? NSRegularExpression(
        pattern: "player=(\\d+)",
        options: []
    )
    private let playerEntityRegex = try? NSRegularExpression(
        pattern: "Player EntityID=\\d+\\s+PlayerID=(\\d+)\\s+GameAccountId=\\[hi=(\\d+)\\s+lo=(\\d+)\\]",
        options: []
    )
    private let playerNameRegex = try? NSRegularExpression(
        pattern: "PlayerID=(\\d+),\\s+PlayerName=([^\\s]+)",
        options: []
    )
    private let entityNameRegex = try? NSRegularExpression(
        pattern: "TAG_CHANGE Entity=([^\\s]+)\\s+tag=",
        options: []
    )

    var onStateUpdate: ((PartialGameState) -> Void)?
    var onError: ((String) -> Void)?
    var onLogPathResolved: ((String) -> Void)?
    var onLocalPlayerResolved: ((Int, String) -> Void)?

    init(logURL: URL? = nil) {
        if let logURL {
            self.logURL = logURL
        } else {
            self.logURL = PowerLogMonitor.resolveDefaultLogURL()
        }
    }

    @discardableResult
    func start() -> Bool {
        if fileHandle != nil { return true }
        onLogPathResolved?(logURL.path)
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            onError?("未找到 Power.log，请先启用日志并重启游戏。")
            return false
        }

        do {
            let handle = try FileHandle(forReadingFrom: logURL)
            fileHandle = handle
            handle.seekToEndOfFile()
            handle.readabilityHandler = { [weak self] file in
                self?.queue.async {
                    let data = file.availableData
                    if data.isEmpty { return }
                    self?.process(data: data)
                }
            }
            return true
        } catch {
            onError?("打开 Power.log 失败：\(error.localizedDescription)")
            return false
        }
    }

    func stop() {
        guard let handle = fileHandle else { return }
        handle.readabilityHandler = nil
        try? handle.close()
        fileHandle = nil
        buffer.removeAll(keepingCapacity: true)
        localPlayerId = nil
        lastTagValues.removeAll(keepingCapacity: true)
        resourcesByPlayer.removeAll(keepingCapacity: true)
        playerNameToId.removeAll(keepingCapacity: true)
    }

    private func process(data: Data) {
        buffer.append(data)
        let newline = Data([0x0A])

        while let range = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            let line = String(decoding: lineData, as: UTF8.self)
            handleLine(line)
        }
    }

    private func handleLine(_ line: String) {
        resolvePlayerNameMapping(from: line)
        if localPlayerId == nil {
            resolveLocalPlayerId(from: line)
        }
        guard line.contains("TAG_CHANGE") else { return }
        guard let (rawTag, rawValue) = extractTagValue(from: line) else { return }

        let tag = normalizeTag(rawTag)
        let intValue = Int(rawValue)

        if tag == "LOCAL_PLAYER", let intValue {
            localPlayerId = intValue
            return
        }

        let entityPlayerId = extractPlayerId(from: line)
        var partial = PartialGameState(timestamp: Date(), turn: nil, gold: nil, health: nil, tavernTier: nil, phase: nil, step: nil)
        var hasUpdate = false

        switch tag {
        case "TURN":
            if let intValue {
                partial.turn = intValue
                hasUpdate = true
            }
        case "RESOURCES":
            if let intValue, let entityPlayerId {
                updateResources(playerId: entityPlayerId, resources: intValue, tempResources: nil, resourcesUsed: nil, partial: &partial, hasUpdate: &hasUpdate)
            }
        case "TEMP_RESOURCES":
            if let intValue, let entityPlayerId {
                updateResources(playerId: entityPlayerId, resources: nil, tempResources: intValue, resourcesUsed: nil, partial: &partial, hasUpdate: &hasUpdate)
            }
        case "RESOURCES_USED":
            if let intValue, let entityPlayerId {
                updateResources(playerId: entityPlayerId, resources: nil, tempResources: nil, resourcesUsed: intValue, partial: &partial, hasUpdate: &hasUpdate)
            }
        case "HEALTH":
            if let intValue, let entityPlayerId, shouldUsePlayer(entityPlayerId) {
                partial.health = intValue
                hasUpdate = true
            }
        case "PLAYER_TECH_LEVEL":
            if let intValue, let entityPlayerId, shouldUsePlayer(entityPlayerId) {
                partial.tavernTier = intValue
                hasUpdate = true
            }
        case "STEP":
            partial.step = rawValue
            hasUpdate = true
        case "GAMETAG_2022":
            if let intValue {
                updatePhase(tag: tag, value: intValue, partial: &partial, hasUpdate: &hasUpdate)
            }
        case "GAMETAG_3533":
            if let intValue {
                updatePhase(tag: tag, value: intValue, partial: &partial, hasUpdate: &hasUpdate)
            }
        default:
            break
        }

        if hasUpdate {
            DispatchQueue.main.async { [weak self] in
                self?.onStateUpdate?(partial)
            }
        }
    }

    private func extractTagValue(from line: String) -> (String, String)? {
        guard let regex = tagValueRegex else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }
        guard let tagRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        let tag = String(line[tagRange])
        let value = String(line[valueRange])
        return (tag, value)
    }

    private func extractPlayerId(from line: String) -> Int? {
        if let regex = inlinePlayerRegex {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, options: [], range: range),
               let idRange = Range(match.range(at: 1), in: line) {
                return Int(line[idRange])
            }
        }

        if let regex = entityPlayerRegex {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, options: [], range: range),
               let idRange = Range(match.range(at: 1), in: line),
               let playerId = Int(line[idRange]) {
                return playerId
            }
        }

        if let name = extractEntityName(from: line),
           let playerId = playerNameToId[name] {
            return playerId
        }

        return nil
    }

    private func isLocalPlayer(_ entityPlayerId: Int?) -> Bool {
        guard let localPlayerId else { return true }
        guard let entityPlayerId else { return false }
        return localPlayerId == entityPlayerId
    }

    private func shouldUsePlayer(_ entityPlayerId: Int) -> Bool {
        guard let localPlayerId else { return false }
        return localPlayerId == entityPlayerId
    }

    private func normalizeTag(_ tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.hasPrefix("GAMETAG_") {
            return trimmed
        }
        if let _ = Int(trimmed) {
            return "GAMETAG_\(trimmed)"
        }
        return trimmed
    }

    private func updatePhase(tag: String, value: Int, partial: inout PartialGameState, hasUpdate: inout Bool) {
        let previous = lastTagValues[tag]
        lastTagValues[tag] = value

        if tag == "GAMETAG_2022", previous == 1, value == 0 {
            partial.phase = .combat
            hasUpdate = true
        } else if tag == "GAMETAG_3533", previous == 1, value == 0 {
            partial.phase = .shopping
            hasUpdate = true
        }
    }

    private func updateResources(
        playerId: Int,
        resources: Int?,
        tempResources: Int?,
        resourcesUsed: Int?,
        partial: inout PartialGameState,
        hasUpdate: inout Bool
    ) {
        var current = resourcesByPlayer[playerId] ?? PlayerResources()
        if let resources {
            current.resources = resources
            current.hasResources = true
        }
        if let tempResources {
            current.tempResources = tempResources
            current.hasTempResources = true
        }
        if let resourcesUsed {
            current.resourcesUsed = resourcesUsed
            current.hasResourcesUsed = true
        }
        resourcesByPlayer[playerId] = current

        guard shouldUsePlayer(playerId) else { return }
        guard current.hasResources || current.hasTempResources else { return }
        let remaining = max(0, current.resources + current.tempResources - current.resourcesUsed)
        partial.gold = remaining
        hasUpdate = true
    }

    private func resolveLocalPlayerId(from line: String) {
        guard let regex = playerEntityRegex else { return }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let playerIdRange = Range(match.range(at: 1), in: line),
              let hiRange = Range(match.range(at: 2), in: line),
              let loRange = Range(match.range(at: 3), in: line) else {
            return
        }
        let playerId = Int(line[playerIdRange]) ?? 0
        let hi = Int64(line[hiRange]) ?? 0
        let lo = Int64(line[loRange]) ?? 0
        if playerId > 0 && (hi != 0 || lo != 0) {
            localPlayerId = playerId
            if let name = playerNameToId.first(where: { $0.value == playerId })?.key {
                onLocalPlayerResolved?(playerId, name)
            }
        }
    }

    private func resolvePlayerNameMapping(from line: String) {
        guard let regex = playerNameRegex else { return }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let idRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line) else {
            return
        }
        let playerId = Int(line[idRange]) ?? 0
        let name = String(line[nameRange])
        if playerId > 0 && !name.isEmpty {
            playerNameToId[name] = playerId
            if localPlayerId == playerId {
                onLocalPlayerResolved?(playerId, name)
            }
        }
    }

    private func extractEntityName(from line: String) -> String? {
        guard let regex = entityNameRegex else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[nameRange])
    }

    private static func resolveDefaultLogURL() -> URL {
        let fileManager = FileManager.default

        let appLogsRoot = URL(fileURLWithPath: "/Applications/Hearthstone/Logs")
        if let url = latestPowerLog(in: appLogsRoot) {
            return url
        }

        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Logs/Blizzard Entertainment/Hearthstone/Power.log")
    }

    private static func latestPowerLog(in root: URL) -> URL? {
        let fileManager = FileManager.default
        guard let folders = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let candidates = folders.filter { $0.hasDirectoryPath }
        let sorted = candidates.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        for folder in sorted {
            let logURL = folder.appendingPathComponent("Power.log")
            if fileManager.fileExists(atPath: logURL.path) {
                return logURL
            }
        }

        return nil
    }
}

private struct PlayerResources {
    var resources: Int = 0
    var tempResources: Int = 0
    var resourcesUsed: Int = 0
    var hasResources: Bool = false
    var hasTempResources: Bool = false
    var hasResourcesUsed: Bool = false
}
