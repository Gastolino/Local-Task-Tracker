import SwiftUI

@main
struct LocalTaskTrackerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var monitor = AppMonitorService()

    var body: some Scene {

        // ── Menu bar icon ──────────────────────────────────────────────────
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            // Filled circle = recording, clock = paused/locked.
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.hierarchical)
                .help("Local Task Tracker")
        }
        .menuBarExtraStyle(.window)

        // ── Main window ────────────────────────────────────────────────────
        Window("Local Task Tracker", id: "main") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(monitor)
                .frame(minWidth: 900, minHeight: 640)
                .onDisappear { AppDelegate.hideMainWindow() }
        }
        .defaultSize(width: 1_020, height: 720)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Suppress the default New menu item — there is no document model.
            CommandGroup(replacing: .newItem) {}
        }
    }

    private var menuBarIcon: String {
        if appState.isLocked { return "lock.fill" }
        return appState.isRecording ? "record.circle.fill" : "clock"
    }
}
