import AppKit

enum OverlayWindowConfigurator {
    static func apply(to window: NSWindow) {
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
