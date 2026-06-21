import AppKit
import ObjectiveC

/// Keeps NanoPlayer's Dock icon from being replaced.
///
/// libmpv's Cocoa backend sets `NSApp.applicationIconImage` to mpv's own icon
/// when it creates its window, which replaces our bundle icon shortly after launch
/// (the "icon flashes/switches" symptom). We swizzle the setter, install our icon
/// once, then lock — any later change (mpv's) is dropped, so our icon stays.
enum IconLock {
    fileprivate static var locked = false

    static func install() {
        guard
            let original = class_getInstanceMethod(
                NSApplication.self, #selector(setter: NSApplication.applicationIconImage)),
            let replacement = class_getInstanceMethod(
                NSApplication.self, #selector(NSApplication.np_setApplicationIconImage(_:)))
        else { return }
        method_exchangeImplementations(original, replacement)

        // Install our bundle icon once (before locking), then lock.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        locked = true
    }
}

extension NSApplication {
    /// After swizzling, this implementation backs `setApplicationIconImage:`.
    @objc dynamic func np_setApplicationIconImage(_ image: NSImage?) {
        if IconLock.locked {
            if ProcessInfo.processInfo.environment["NP_LOG"] != nil {
                NSLog("NP_DIAG dropped applicationIconImage change (kept NanoPlayer icon)")
            }
            return
        }
        // Swizzled: this selector now points at the original setter.
        self.np_setApplicationIconImage(image)
    }
}
