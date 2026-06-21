import AppKit

/// Captures keyboard input app-wide and forwards IINA-aligned shortcuts to the
/// `Player` as mpv commands.
///
/// Why host-side: when libmpv is embedded in a host NSApplication, mpv's own
/// window does not receive keyboard events, so its native bindings never fire.
/// A local event monitor sees every key the app gets (regardless of which window
/// is key) and forwards it; handled keys are consumed so nothing double-fires.
final class KeyboardHandler {
    private weak var player: Player?
    private var monitor: Any?

    init(player: Player) {
        self.player = player
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handle(event) ? nil : event   // nil = consumed
        }
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }

    /// Returns true if the key was handled (and should be consumed).
    private func handle(_ e: NSEvent) -> Bool {
        guard let player = player else { return false }
        // Don't steal keys from a modal panel (e.g. the Open dialog needs arrows).
        if NSApp.modalWindow != nil { return false }

        if e.modifierFlags.contains(.command) {
            // ⌘← / ⌘→ = previous / next episode; leave other ⌘ combos to the menu.
            switch e.keyCode {
            case 124: player.nextEpisode(); return true   // ⌘→
            case 123: player.prevEpisode(); return true   // ⌘←
            default:  return false
            }
        }

        switch e.keyCode {
        case 49:  player.togglePause();      return true   // space
        case 124: player.seekRelative(5);    return true   // → 快进 5s
        case 123: player.seekRelative(-5);   return true   // ← 后退 5s
        case 126: player.addVolume(5);       return true   // ↑ 音量+
        case 125: player.addVolume(-5);      return true   // ↓ 音量-
        default:
            switch e.charactersIgnoringModifiers?.lowercased() {
            case "f": player.toggleFullscreen(); return true   // F 全屏
            case "m": player.toggleMute();       return true   // M 静音
            case "<": player.prevEpisode();      return true   // < 上一集（兜底）
            case ">": player.nextEpisode();      return true   // > 下一集（兜底）
            default:  return false
            }
        }
    }
}
