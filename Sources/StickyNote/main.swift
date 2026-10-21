import AppKit

// Entry point. Menus and windows are built in code (no storyboard / nib),
// so a plain Swift Package executable can be wrapped into a .app bundle.
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()
