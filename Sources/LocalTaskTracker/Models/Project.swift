import Foundation

// MARK: - Project

struct Project: Identifiable, Hashable {
    let id: Int
    var name: String
    var color: String          // hex, e.g. "#5856D6"
    var description: String?
    let createdAt: Date
    var isArchived: Bool

    static let presetColors: [String] = [
        "#5856D6", "#007AFF", "#34C759", "#FF9500",
        "#FF3B30", "#FF2D55", "#AF52DE", "#00C7BE",
        "#FFCC00", "#8E8E93",
    ]
}

// MARK: - Session

struct Session: Identifiable {
    let id: Int
    let projectID: Int
    var projectName: String
    var projectColor: String
    var label: String?
    var startedAt: Date
    var endedAt: Date?
    var notes: String?
    let createdAt: Date

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var isActive: Bool { endedAt == nil }
}

// MARK: - ProjectNote

struct ProjectNote: Identifiable {
    let id: Int
    let projectID: Int
    var content: String
    let createdAt: Date
    var updatedAt: Date
}

// MARK: - ProjectStats

struct ProjectStats {
    let totalSeconds: TimeInterval
    let thisWeekSeconds: TimeInterval
    let todaySeconds: TimeInterval
    let sessionCount: Int
}
