import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as an accessory (menu-bar only) — no Dock icon.
        // The main window is opened explicitly by the user via the menu bar.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing the main window should not quit the app; it stays in the menu bar.
        return false
    }

    /// Call this to bring the main window to front and show the Dock icon.
    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == "main" {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    /// Call when the main window closes to hide the Dock icon again.
    static func hideMainWindow() {
        NSApp.setActivationPolicy(.accessory)
    }
}
