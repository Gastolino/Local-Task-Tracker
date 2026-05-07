import SwiftUI
import CryptoKit

// MARK: - ActiveSession

/// A session that was started from the menu bar and hasn't ended yet.
struct ActiveSession {
    let dbID: Int           // row ID in the sessions table
    let project: Project
    let label: String
    let startedAt: Date
}

// MARK: - AppState

final class AppState: ObservableObject {

    // MARK: - Lock state

    @Published var isLocked = true

    private(set) var encryptionKey: SymmetricKey?

    // MARK: - Recording state

    @Published var isRecording   = false
    @Published var currentApp    = ""
    @Published var recordingStart: Date?

    // MARK: - Active project session

    @Published var activeSession: ActiveSession?

    // MARK: - Auth

    var isPasswordConfigured: Bool {
        CryptoService.shared.isPasswordConfigured
    }

    func configurePassword(_ password: String) -> Bool {
        guard let key = CryptoService.shared.setPassword(password) else { return false }
        encryptionKey = key
        isLocked      = false
        isRecording   = true
        recordingStart = Date()
        return true
    }

    func unlock(password: String) -> Bool {
        guard let key = CryptoService.shared.verifyAndDeriveKey(password) else { return false }
        encryptionKey  = key
        isLocked       = false
        isRecording    = true
        recordingStart = Date()
        restoreActiveSession()
        return true
    }

    func lock() {
        if let session = activeSession {
            ProjectService.shared.endSession(id: session.dbID)
        }
        encryptionKey  = nil
        isLocked       = true
        isRecording    = false
        currentApp     = ""
        recordingStart = nil
        activeSession  = nil
    }

    // MARK: - Recording control

    func startRecording() {
        guard !isLocked else { return }
        isRecording    = true
        recordingStart = Date()
    }

    func stopRecording() {
        isRecording    = false
        recordingStart = nil
    }

    // MARK: - Project session control

    /// Start a quick session for a project from the menu bar.
    func startSession(project: Project, label: String) {
        guard let session = ProjectService.shared.createSession(
            projectID: project.id,
            label:     label.isEmpty ? nil : label,
            startedAt: Date(),
            endedAt:   nil,
            notes:     nil
        ) else { return }
        activeSession = ActiveSession(
            dbID: session.id, project: project, label: label, startedAt: Date()
        )
    }

    /// End the active quick session, return the completed Session.
    @discardableResult
    func endActiveSession() -> Session? {
        guard let active = activeSession else { return nil }
        ProjectService.shared.endSession(id: active.dbID)
        activeSession = nil
        let sessions = ProjectService.shared.sessions(forProject: active.project.id)
        return sessions.first { $0.id == active.dbID }
    }

    // MARK: - Elapsed time display

    var elapsedString: String {
        guard let start = activeSession?.startedAt ?? recordingStart else { return "—" }
        let secs = Int(Date().timeIntervalSince(start))
        let h = secs / 3600; let m = (secs % 3600) / 60; let s = secs % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    // MARK: - Private

    /// On unlock, re-attach any open session from the DB (handles app restarts).
    private func restoreActiveSession() {
        let projects = ProjectService.shared.allProjects()
        for project in projects {
            let sessions = ProjectService.shared.sessions(forProject: project.id)
            if let open = sessions.first(where: { $0.isActive }) {
                activeSession = ActiveSession(
                    dbID:      open.id,
                    project:   project,
                    label:     open.label ?? "",
                    startedAt: open.startedAt
                )
                return
            }
        }
    }
}
