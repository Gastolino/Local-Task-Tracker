import Foundation

/// Single source-of-truth for the data directory and database path.
/// Both DatabaseService and ProjectService open the same file.
enum AppPaths {
    static let dataDir: URL = {
        let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("LocalTaskTracker")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let dbPath: String = dataDir.appendingPathComponent("tracker.db").path
}
