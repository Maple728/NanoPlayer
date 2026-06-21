import AppKit

// Entry point. Top-level executable code must live in `main.swift`.
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
