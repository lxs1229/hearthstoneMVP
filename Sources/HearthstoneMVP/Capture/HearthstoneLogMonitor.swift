import Foundation

final class HearthstoneLogMonitor {
    private struct TailState {
        let url: URL
        var handle: FileHandle?
        var buffer = Data()
    }

    private let queue = DispatchQueue(label: "hs.hearthstone.log.queue")
    private var tails: [TailState] = []
    private var currentGameMode: GameMode?

    private let gameTypeRegex = try? NSRegularExpression(
        pattern: "GameType=([A-Z_]+|\\d+)",
        options: []
    )
    private let stepRegex = try? NSRegularExpression(
        pattern: "STEP=([A-Z_]+)",
        options: []
    )
    private let sceneRegex = try? NSRegularExpression(
        pattern: "Bacon|BATTLEGROUNDS",
        options: [.caseInsensitive]
    )

    var onStateUpdate: ((PartialGameState) -> Void)?
    var onError: ((String) -> Void)?

    func start() -> Bool {
        stop()
        tails = resolveLogURLs().map { TailState(url: $0, handle: nil, buffer: Data()) }
        guard !tails.isEmpty else {
            onError?("未找到 Hearthstone.log 或 GameNetLogger.log，无法补充日志信息。")
            return false
        }

        var started = false
        for index in tails.indices {
            let url = tails[index].url
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let handle = try FileHandle(forReadingFrom: url)
                tails[index].handle = handle
                handle.seekToEndOfFile()
                handle.readabilityHandler = { [weak self] file in
                    self?.queue.async {
                        let data = file.availableData
                        if data.isEmpty { return }
                        self?.process(data: data, for: url)
                    }
                }
                started = true
            } catch {
                onError?("无法打开日志 \(url.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        if !started {
            onError?("日志文件无法读取，请检查权限或是否已开启日志。")
        }

        return started
    }

    func stop() {
        for index in tails.indices {
            if let handle = tails[index].handle {
                handle.readabilityHandler = nil
                try? handle.close()
            }
        }
        tails.removeAll(keepingCapacity: true)
        currentGameMode = nil
    }

    private func process(data: Data, for url: URL) {
        guard let index = tails.firstIndex(where: { $0.url == url }) else { return }
        tails[index].buffer.append(data)
        let newline = Data([0x0A])

        while let range = tails[index].buffer.range(of: newline) {
            let lineData = tails[index].buffer.subdata(in: 0..<range.lowerBound)
            tails[index].buffer.removeSubrange(0..<range.upperBound)
            let line = String(decoding: lineData, as: UTF8.self)
            handleLine(line)
        }
    }

    private func handleLine(_ line: String) {
        if let mode = detectGameMode(from: line) {
            currentGameMode = mode
            emitPartial(mode: mode, step: nil, phase: nil)
        }

        if let step = detectStep(from: line) {
            let phase = phase(for: step)
            emitPartial(mode: currentGameMode, step: step, phase: phase)
        }

        if currentGameMode == nil, sceneRegex?.firstMatch(
            in: line,
            options: [],
            range: NSRange(line.startIndex..<line.endIndex, in: line)
        ) != nil {
            currentGameMode = .battlegrounds
            emitPartial(mode: .battlegrounds, step: nil, phase: nil)
        }
    }

    private func emitPartial(mode: GameMode?, step: String?, phase: GamePhase?) {
        var partial = PartialGameState(
            timestamp: Date(),
            turn: nil,
            gold: nil,
            health: nil,
            tavernTier: nil,
            phase: phase,
            step: step,
            mode: mode
        )
        DispatchQueue.main.async { [weak self] in
            self?.onStateUpdate?(partial)
        }
    }

    private func detectGameMode(from line: String) -> GameMode? {
        guard let regex = gameTypeRegex else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let typeRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let raw = String(line[typeRange]).uppercased()
        if raw.contains("BATTLEGROUNDS") || raw.contains("BACON") {
            return .battlegrounds
        }
        if raw == "8" || raw == "50" { return .battlegrounds }
        return .other
    }

    private func detectStep(from line: String) -> String? {
        guard let regex = stepRegex else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let stepRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[stepRange])
    }

    private func phase(for step: String) -> GamePhase? {
        let upper = step.uppercased()
        if upper.contains("COMBAT") { return .combat }
        if upper.contains("MAIN_START") || upper.contains("MAIN_READY") || upper.contains("MAIN_ACTION") {
            return .shopping
        }
        if upper.contains("FINAL_WRAPUP") { return .combat }
        return nil
    }

    private func resolveLogURLs() -> [URL] {
        let fm = FileManager.default
        var urls: [URL] = []
        let defaults: [URL] = [
            URL(fileURLWithPath: "/Applications/Hearthstone/Logs/Hearthstone.log"),
            URL(fileURLWithPath: "/Applications/Hearthstone/Logs/GameNetLogger.log"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Blizzard Entertainment/Hearthstone/Hearthstone.log"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Blizzard Entertainment/Hearthstone/GameNetLogger.log")
        ]

        for url in defaults where fm.fileExists(atPath: url.path) {
            urls.append(url)
        }
        return Array(Set(urls))
    }
}
