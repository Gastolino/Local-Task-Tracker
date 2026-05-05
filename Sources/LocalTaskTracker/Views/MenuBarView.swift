import SwiftUI

/// Content of the menu bar popover.
struct MenuBarView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow

    @State private var summary: (activeSeconds: TimeInterval, appCount: Int) = (0, 0)
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            Divider().padding(.vertical, 4)
            controlsSection
            Divider().padding(.vertical, 4)
            todaySection
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            reloadSummary()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                reloadSummary()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text(statusLabel)
                    .font(.subheadline.weight(.semibold))
                if !appState.isLocked && appState.isRecording {
                    Text(appState.currentApp.isEmpty ? "Watching…" : appState.currentApp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !appState.isLocked && appState.isRecording {
                Text(appState.elapsedString)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 6) {
            if appState.isLocked {
                menuButton("Unlock", icon: "lock.open.fill", tint: .accentColor) {
                    openMainWindow()
                }
            } else if appState.isRecording {
                menuButton("Pause Recording", icon: "pause.circle.fill", tint: .orange) {
                    appState.stopRecording()
                }
            } else {
                menuButton("Resume Recording", icon: "record.circle.fill", tint: .green) {
                    appState.startRecording()
                }
            }

            menuButton("Open Tracker", icon: "calendar", tint: .accentColor) {
                openMainWindow()
            }

            Divider()

            menuButton("Lock & Quit", icon: "power", tint: .red) {
                ScreenshotService.shared.stop()
                appState.lock()
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Today summary

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            HStack {
                Label(fmt(summary.activeSeconds), systemImage: "clock.fill")
                    .font(.caption)
                Spacer()
                Text("\(summary.appCount) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(appState.isLocked ? 0.4 : 1)
    }

    // MARK: - Helpers

    private func menuButton(
        _ label: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }

    private func openMainWindow() {
        AppDelegate.showMainWindow()
        openWindow(id: "main")
    }

    private func reloadSummary() {
        guard !appState.isLocked else { return }
        summary = DatabaseService.shared.todaySummary()
    }

    private var statusLabel: String {
        if appState.isLocked    { return "Locked" }
        if appState.isRecording { return "Recording" }
        return "Paused"
    }

    private var statusColor: Color {
        if appState.isLocked    { return .gray }
        if appState.isRecording { return .red }
        return .orange
    }

    private func fmt(_ s: TimeInterval) -> String {
        let t = Int(s)
        let h = t / 3600; let m = (t % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m active" }
        return "\(m)m active"
    }
}
