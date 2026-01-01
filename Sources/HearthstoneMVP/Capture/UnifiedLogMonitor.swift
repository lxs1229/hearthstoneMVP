import Foundation

final class UnifiedLogMonitor {
    private let powerMonitor: PowerLogMonitor
    private let hearthstoneMonitor = HearthstoneLogMonitor()

    var onStateUpdate: ((PartialGameState) -> Void)?
    var onError: ((String) -> Void)?
    var onLogPathResolved: ((String) -> Void)?
    var onLocalPlayerResolved: ((Int, String) -> Void)?

    init(powerMonitor: PowerLogMonitor = PowerLogMonitor()) {
        self.powerMonitor = powerMonitor
        wireCallbacks()
    }

    func start() -> Bool {
        var started = false
        let powerStarted = powerMonitor.start()
        let hsStarted = hearthstoneMonitor.start()
        started = powerStarted || hsStarted
        if !started {
            onError?("未能启动任何日志监听，请确认日志路径与权限。")
        }
        return started
    }

    func stop() {
        powerMonitor.stop()
        hearthstoneMonitor.stop()
    }

    private func wireCallbacks() {
        powerMonitor.onStateUpdate = { [weak self] partial in
            self?.onStateUpdate?(partial)
        }
        powerMonitor.onLogPathResolved = { [weak self] path in
            self?.onLogPathResolved?(path)
        }
        powerMonitor.onLocalPlayerResolved = { [weak self] id, name in
            self?.onLocalPlayerResolved?(id, name)
        }
        powerMonitor.onError = { [weak self] message in
            self?.onError?(message)
        }

        hearthstoneMonitor.onStateUpdate = { [weak self] partial in
            self?.onStateUpdate?(partial)
        }
        hearthstoneMonitor.onError = { [weak self] message in
            self?.onError?(message)
        }
    }
}
