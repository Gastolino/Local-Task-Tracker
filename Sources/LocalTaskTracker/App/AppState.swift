import SwiftUI
import CryptoKit

/// Central state shared across the entire app via @EnvironmentObject.
final class AppState: ObservableObject {

    // MARK: - Lock state

    @Published var isLocked = true

    /// In-memory only — zeroed when the app locks.
    private(set) var encryptionKey: SymmetricKey?

    // MARK: - Recording state

    @Published var isRecording = false
    @Published var currentApp = ""
    @Published var recordingStart: Date?

    // MARK: - Auth

    var isPasswordConfigured: Bool {
        CryptoService.shared.isPasswordConfigured
    }

    /// Called on first launch to set the master password.
    /// Returns true on success.
    func configurePassword(_ password: String) -> Bool {
        guard let key = CryptoService.shared.setPassword(password) else { return false }
        encryptionKey = key
        isLocked = false
        isRecording = true
        recordingStart = Date()
        return true
    }

    /// Verifies the password, derives the encryption key, and unlocks the UI.
    func unlock(password: String) -> Bool {
        guard let key = CryptoService.shared.verifyAndDeriveKey(password) else { return false }
        encryptionKey = key
        isLocked = false
        isRecording = true
        recordingStart = Date()
        return true
    }

    func lock() {
        // Overwrite the key in memory before releasing the reference.
        encryptionKey = nil
        isLocked = true
        isRecording = false
        currentApp = ""
        recordingStart = nil
    }

    // MARK: - Recording control

    func startRecording() {
        guard !isLocked else { return }
        isRecording = true
        recordingStart = Date()
    }

    func stopRecording() {
        isRecording = false
        recordingStart = nil
    }

    /// Elapsed time string for the menu bar / status display.
    var elapsedString: String {
        guard let start = recordingStart else { return "—" }
        let secs = Int(Date().timeIntervalSince(start))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
}
