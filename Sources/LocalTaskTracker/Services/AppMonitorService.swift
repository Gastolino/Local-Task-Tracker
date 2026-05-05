import AppKit
import Combine

/// Watches NSWorkspace for work-app launches and polls the DB for events
/// written by the Python daemon.  Either path can trigger the UI prompt.
final class AppMonitorService: ObservableObject {

    /// Non-nil when a work app has launched and the user hasn't been asked yet.
    @Published var pendingPromptApp: String?
    @Published var pendingEventID: Int?

    private var cancellables = Set<AnyCancellable>()
    private var pollTimer: AnyCancellable?

    /// Apps that should trigger a "Are you working?" prompt.
    private let workApps: Set<String> = [
        "Microsoft PowerPoint", "Microsoft Word", "Microsoft Excel",
        "Microsoft Teams", "Adobe Photoshop 2025", "Adobe Photoshop 2024",
        "Adobe Photoshop", "Adobe Illustrator 2025", "Adobe Illustrator 2024",
        "Adobe Illustrator", "Adobe InDesign 2025", "Adobe InDesign 2024",
        "Adobe InDesign", "Adobe Premiere Pro 2025", "Adobe Premiere Pro 2024",
        "Adobe Premiere Pro", "Adobe After Effects 2025", "Adobe After Effects 2024",
        "Adobe After Effects", "Adobe Lightroom Classic",
        "Figma", "Sketch", "Keynote", "Pages", "Numbers",
        "Final Cut Pro", "Logic Pro", "Xcode", "Visual Studio Code",
        "DaVinci Resolve", "Blender", "Cinema 4D",
    ]

    private var promptedThisSession = Set<String>()

    init() {
        // Watch for app launches in real-time.
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in self?.handleLaunch(note) }
            .store(in: &cancellables)

        // Also watch app activations (user switches to an already-open work app).
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in self?.handleLaunch(note) }
            .store(in: &cancellables)

        // Poll DB for events written by the Python daemon (runs every 10 s).
        pollTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.pollDB() }
    }

    // MARK: - Private

    private func handleLaunch(_ note: Notification) {
        guard pendingPromptApp == nil,
              let app  = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let name = app.localizedName,
              workApps.contains(name),
              !promptedThisSession.contains(name)
        else { return }
        promptedThisSession.insert(name)
        pendingPromptApp = name
    }

    private func pollDB() {
        guard pendingPromptApp == nil else { return }
        let events = DatabaseService.shared.pendingLaunchEvents()
        guard let first = events.first else { return }
        // Only prompt if not already prompted this session for this app.
        if !promptedThisSession.contains(first.appName) {
            promptedThisSession.insert(first.appName)
            pendingEventID   = first.id
            pendingPromptApp = first.appName
        } else {
            // Mark as seen without prompting.
            DatabaseService.shared.markLaunchEventPrompted(first.id)
        }
    }

    func dismissPrompt() {
        if let id = pendingEventID {
            DatabaseService.shared.markLaunchEventPrompted(id)
        }
        pendingPromptApp = nil
        pendingEventID   = nil
    }
}
