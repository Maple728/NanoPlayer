import Foundation
import AppKit
import UniformTypeIdentifiers
import Cmpv

/// Drives libmpv and owns all player behaviour.
///
/// On macOS this mpv build is Vulkan/Metal-only and its video backend does NOT
/// support `--wid` embedding (it always creates its own window). To keep
/// `vo=gpu-next` + HDR passthrough, we let mpv own the single video window (with
/// its native OSC and mouse handling) and use libmpv to add behaviour on top:
/// whole-series "binge" expansion, file opening, and keyboard-driven playback
/// control forwarded by `KeyboardHandler`.
///
/// Threading: every libmpv call runs on the serial queue `q`.
final class Player {
    private let mpv = MPV()
    private let q = DispatchQueue(label: "dev.local.nanoplayer.mpv")
    private var started = false
    private var ready = false                     // q only — mpv initialized & accepting commands
    private var pending: [URL] = []               // q only — files requested before mpv was ready
    private var expandedSeries = Set<String>()   // q only — series already expanded

    /// Supported media extensions (open panel + series scan).
    static let mediaTypes = ["mp4","mkv","mov","m4v","webm","avi","ts","flv","wmv",
                             "mp3","flac","wav","aac","m4a","ogg","opus"]

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true

        // User's command + a self-contained, native mpv window.
        mpv.setOption("vo", "gpu-next")
        mpv.setOption("target-colorspace-hint", "yes")   // HDR passthrough to macOS
        mpv.setOption("hwdec", "videotoolbox")           // Apple Silicon HW decode
        mpv.setOption("keep-open", "no")                 // auto-advance to next episode
        mpv.setOption("idle", "yes")
        mpv.setOption("force-window", "yes")             // show the window immediately
        mpv.setOption("osc", "yes")                      // native on-screen controller
        mpv.setOption("script-opts", "osc-idlescreen=no") // hide mpv's idle logo / "drop files" splash
        mpv.setOption("input-default-bindings", "yes")
        mpv.setOption("input-vo-keyboard", "yes")
        mpv.setOption("input-media-keys", "yes")
        mpv.setOption("volume-max", "130")

        let env = ProcessInfo.processInfo.environment
        if env["NP_LOG"] != nil {
            mpv.setOption("terminal", "yes")
            mpv.setOption("msg-level", "all=v")
        } else {
            mpv.setOption("terminal", "no")
        }
        if let sock = env["NP_IPC"] { mpv.setOption("input-ipc-server", sock) }

        // In a self-contained build, point the Vulkan loader at our bundled
        // MoltenVK driver (gpu-next's backend) so rendering works without Homebrew.
        if let res = Bundle.main.resourcePath {
            let icd = res + "/vulkan/icd.d/MoltenVK_icd.json"
            if FileManager.default.fileExists(atPath: icd) {
                setenv("VK_ICD_FILENAMES", icd, 1)   // older Vulkan loaders
                setenv("VK_DRIVER_FILES", icd, 1)    // newer Vulkan loaders
            }
        }

        guard mpv.initialize() else {
            NSLog("NanoPlayer: mpv_initialize failed")
            return
        }

        // Custom idle screen (our logo) — replaces mpv's disabled idle logo.
        if let lua = Bundle.main.path(forResource: "idle-logo", ofType: "lua") {
            mpv.command(["load-script", lua])
        }

        // Mouse (handled natively by mpv's window): single-click = pause,
        // double-click = fullscreen. Keyboard is handled by the host
        // (KeyboardHandler) because the embedded mpv window doesn't receive keys.
        mpv.command(["keybind", "MBTN_LEFT", "cycle pause"])
        mpv.command(["keybind", "MBTN_LEFT_DBL", "cycle fullscreen"])

        mpv.setWakeup { [weak self] in
            self?.q.async { self?.drainEvents() }
        }

        // mpv is now initialized; play anything that arrived before we were ready
        // (e.g. a Finder "Open With" Apple Event delivered before start()).
        q.async { [weak self] in
            guard let self = self else { return }
            self.ready = true
            if !self.pending.isEmpty {
                let files = self.pending
                self.pending = []
                self.load(files)
            }
        }
    }

    // MARK: - Event loop (q)

    private func drainEvents() {
        while let ev = mpv.nextEvent() {
            switch ev.pointee.event_id {
            case MPV_EVENT_FILE_LOADED:
                maybeExpandSeries()
            case MPV_EVENT_SHUTDOWN:
                exit(0)                          // mpv window closed
            default:
                break
            }
        }
    }

    /// When a lone file has just loaded, add the rest of its episode series to the
    /// playlist (sorted), without reloading the file that is already playing.
    /// Runs for every entry point: open panel, Finder, command line, drag-and-drop.
    private func maybeExpandSeries() {
        guard Int(mpv.getInt("playlist-count") ?? 0) == 1 else { return }
        guard let path = mpv.getString("path") ?? mpv.getString("playlist/0/filename") else { return }
        let url = URL(fileURLWithPath: path)
        guard let parsed = EpisodeMatcher.parse(url) else { return }
        guard !expandedSeries.contains(parsed.seriesKey) else { return }
        expandedSeries.insert(parsed.seriesKey)

        let eps = EpisodeMatcher.episodes(for: url, allowedExtensions: Set(Player.mediaTypes))
        guard eps.count > 1 else { return }
        let anchorPath = url.standardizedFileURL.path
        guard let anchorIdx = eps.firstIndex(where: { $0.standardizedFileURL.path == anchorPath }) else { return }

        // Insert earlier episodes before the (still-playing) anchor and append the
        // later ones. `insert-at` keeps the anchor playing — no flicker / re-decode.
        for (i, e) in eps[..<anchorIdx].enumerated() {
            mpv.command(["loadfile", e.path, "insert-at", String(i)])
        }
        for e in eps[(anchorIdx + 1)...] {
            mpv.command(["loadfile", e.path, "append"])
        }
    }

    // MARK: - Opening files

    /// Open files. A single file triggers whole-series expansion; multiple files
    /// are loaded as given. Buffers until mpv is initialized (Finder "Open With"
    /// can deliver files before `start()` finishes).
    func open(_ urls: [URL]) {
        q.async { [weak self] in
            guard let self = self, !urls.isEmpty else { return }
            guard self.ready else { self.pending = urls; return }
            self.load(urls)
        }
    }

    /// Runs on q. Replaces the playlist with `urls` (first file plays; a single
    /// file then gets its season auto-expanded via the file-loaded event).
    private func load(_ urls: [URL]) {
        expandedSeries.removeAll()
        mpv.command(["loadfile", urls[0].path, "replace"])
        for u in urls.dropFirst() { mpv.command(["loadfile", u.path, "append"]) }
    }

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = Player.mediaTypes.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { open(panel.urls) }
    }

    /// Ask mpv to quit (emits MPV_EVENT_SHUTDOWN -> exit).
    func quit() { q.async { [weak self] in self?.mpv.command(["quit"]) } }

    // MARK: - Playback control (forwarded by KeyboardHandler)

    private func cmd(_ args: [String]) { q.async { [weak self] in self?.mpv.command(args) } }

    func togglePause()            { cmd(["cycle", "pause"]) }
    func toggleFullscreen()       { cmd(["cycle", "fullscreen"]) }
    func seekRelative(_ s: Double){ cmd(["seek", String(s), "relative+exact"]) }
    func nextEpisode()            { cmd(["playlist-next"]) }
    func prevEpisode()            { cmd(["playlist-prev"]) }
    func addVolume(_ d: Double)   { cmd(["add", "volume", String(d)]) }
    func toggleMute()             { cmd(["cycle", "mute"]) }
}
