import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow

    @State private var summary: (activeSeconds: TimeInterval, appCount: Int) = (0, 0)
    @State private var projects:      [Project] = []
    @State private var showNewSession = false
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            Divider().padding(.vertical, 4)

            if let session = appState.activeSession {
                activeSessionSection(session)
                Divider().padding(.vertical, 4)
            }

            controlsSection
            Divider().padding(.vertical, 4)
            todaySection
        }
        .padding(12)
        .frame(width: 260)
        .onAppear {
            reloadSummary()
            projects = ProjectService.shared.allProjects()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                reloadSummary()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .sheet(isPresented: $showNewSession) {
            QuickSessionView { project, label in
                appState.startSession(project: project, label: label)
            }
            .environmentObject(appState)
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(statusLabel).font(.subheadline.weight(.semibold))
                if !appState.isLocked && !appState.currentApp.isEmpty {
                    Text(appState.currentApp)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if !appState.isLocked {
                Text(appState.elapsedString)
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private func activeSessionSection(_ session: ActiveSession) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: session.project.color))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.project.name)
                    .font(.caption.weight(.semibold)).lineLimit(1)
                if let lbl = Optional(session.label), !lbl.isEmpty {
                    Text(lbl).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                appState.endActiveSession()
            } label: {
                Label("End", systemImage: "stop.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered).controlSize(.mini)
        }
        .padding(.vertical, 2)
    }

    private var controlsSection: some View {
        VStack(spacing: 5) {
            if appState.isLocked {
                menuButton("Unlock", icon: "lock.open.fill", tint: .accentColor) {
                    openMainWindow()
                }
            } else {
                if appState.activeSession == nil {
                    menuButton("Start Session…", icon: "play.circle.fill", tint: .green) {
                        projects = ProjectService.shared.allProjects()
                        showNewSession = true
                    }
                }

                if appState.isRecording {
                    menuButton("Pause Tracking", icon: "pause.circle.fill", tint: .orange) {
                        appState.stopRecording()
                    }
                } else {
                    menuButton("Resume Tracking", icon: "record.circle.fill", tint: .green) {
                        appState.startRecording()
                    }
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

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY")
                .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            HStack {
                Label(fmt(summary.activeSeconds), systemImage: "clock.fill")
                    .font(.caption)
                Spacer()
                Text("\(summary.appCount) apps")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .opacity(appState.isLocked ? 0.4 : 1)
    }

    // MARK: - Helpers

    private func menuButton(_ label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .padding(.vertical, 4).padding(.horizontal, 6)
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
        if appState.isRecording { return "Tracking" }
        return "Paused"
    }

    private var statusColor: Color {
        if appState.isLocked    { return .gray }
        if appState.isRecording { return .red }
        return .orange
    }

    private func fmt(_ s: TimeInterval) -> String {
        let t = Int(s); let h = t / 3600; let m = (t % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m active" }
        return "\(m)m active"
    }
}

// MARK: - QuickSessionView

/// Small sheet opened from the menu bar to start a session immediately.
struct QuickSessionView: View {
    var onStart: (Project, String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var projects:    [Project] = []
    @State private var projectIdx   = 0
    @State private var label        = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Start Session").font(.title3.bold())

            if projects.isEmpty {
                Text("Create a project first in the Projects tab.")
                    .foregroundStyle(.secondary).font(.callout)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Project").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Picker("Project", selection: $projectIdx) {
                        ForEach(projects.indices, id: \.self) { i in
                            HStack {
                                Circle().fill(Color(hex: projects[i].color)).frame(width: 10, height: 10)
                                Text(projects[i].name)
                            }.tag(i)
                        }
                    }.labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Label (optional)").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    TextField("e.g. Design work, Client call…", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { start() }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.escape)
                Spacer()
                Button("Start") { start() }
                    .buttonStyle(.borderedProminent)
                    .disabled(projects.isEmpty)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 320)
        .onAppear { projects = ProjectService.shared.allProjects() }
    }

    private func start() {
        guard !projects.isEmpty else { return }
        onStart(projects[projectIdx], label)
        dismiss()
    }
}
