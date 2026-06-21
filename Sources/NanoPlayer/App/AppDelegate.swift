import AppKit

/// App lifecycle. NanoPlayer is a thin driver around libmpv: mpv owns the single
/// video window (gpu-next + HDR + native OSC/mouse), while this delegate provides
/// the menu bar, file opening, and wires up the host-side keyboard handler.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let player = Player()
    private var keyboard: KeyboardHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        IconLock.install()                          // keep our Dock icon (mpv would replace it)
        player.start()                              // creates mpv's window
        buildMenu()                                 // our menu after mpv, so ours wins
        keyboard = KeyboardHandler(player: player)  // host-side keyboard

        let fileArgs = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        if !fileArgs.isEmpty {
            player.open(fileArgs.map { URL(fileURLWithPath: $0) })
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    /// Files opened from Finder ("Open With…", drag onto the Dock icon). This Apple
    /// Event can arrive before applicationDidFinishLaunching; Player buffers until
    /// mpv is ready, so order doesn't matter.
    func application(_ application: NSApplication, open urls: [URL]) {
        player.open(urls)
    }

    @objc func openFiles() { player.openFilePanel() }
    @objc func performQuit() { player.quit() }

    // MARK: - Menu

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 NanoPlayer",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 NanoPlayer",
                        action: #selector(performQuit),
                        keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        let open = fileMenu.addItem(withTitle: "打开…", action: #selector(openFiles), keyEquivalent: "o")
        open.target = self
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        NSApp.mainMenu = mainMenu
    }
}
