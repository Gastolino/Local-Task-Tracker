import SwiftUI

/// Root view: switches between the lock screen and the main calendar,
/// and overlays the work-app prompt as a sheet.
struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var monitor: AppMonitorService

    var body: some View {
        Group {
            if appState.isLocked {
                LockView()
            } else {
                CalendarView()
                    .onAppear {
                        ScreenshotService.shared.start(appState: appState)
                    }
                    .onDisappear {
                        // Keep capturing even when window is closed;
                        // stop only when the app locks.
                    }
            }
        }
        // Work-app prompt sheet.
        .sheet(
            isPresented: Binding(
                get: { monitor.pendingPromptApp != nil && !appState.isLocked },
                set: { if !$0 { monitor.dismissPrompt() } }
            )
        ) {
            if let app = monitor.pendingPromptApp {
                AppLaunchPromptView(appName: app) { start in
                    if start { appState.startRecording() }
                    monitor.dismissPrompt()
                }
            }
        }
        .onChange(of: appState.isLocked) { locked in
            if locked { ScreenshotService.shared.stop() }
        }
    }
}
