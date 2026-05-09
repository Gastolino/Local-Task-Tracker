import SwiftUI

// MARK: - App tabs

enum AppTab: Hashable {
    case calendar, projects, billing
}

// MARK: - ContentView

/// Root view: shows the lock screen until unlocked, then a tabbed main interface.
struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var monitor: AppMonitorService
    @State private var tab: AppTab = .calendar

    var body: some View {
        Group {
            if appState.isLocked {
                LockView()
            } else {
                mainInterface
                    .onAppear { ScreenshotService.shared.start(appState: appState) }
                    .onChange(of: appState.isLocked) { locked in
                        if locked { ScreenshotService.shared.stop() }
                    }
            }
        }
        // Work-app launch prompt.
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
    }

    // MARK: - Main interface

    private var mainInterface: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            tabContent
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            // Tab switcher
            tabButton(.calendar, "Calendar", "calendar")
            tabButton(.projects, "Projects", "folder.fill")
            tabButton(.billing,  "Billing",  "doc.text.fill")

            Spacer()

            // Active session indicator
            if let session = appState.activeSession {
                activeSessionBadge(session)
            }

            // Lock button
            Button {
                ScreenshotService.shared.stop()
                appState.lock()
            } label: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Lock")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .calendar: CalendarView()
        case .projects: ProjectsView()
        case .billing:  BillingView()
        }
    }

    // MARK: - Sub-views

    private func tabButton(_ t: AppTab, _ label: String, _ icon: String) -> some View {
        Button {
            tab = t
        } label: {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(tab == t ? .semibold : .regular))
                .foregroundStyle(tab == t ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    tab == t
                        ? Color.primary.opacity(0.08)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
    }

    private func activeSessionBadge(_ session: ActiveSession) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: session.project.color))
                .frame(width: 7, height: 7)
            Text(session.project.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text(appState.elapsedString)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                appState.endActiveSession()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("End session")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}
