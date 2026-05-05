import Foundation

struct ActivityRecord: Identifiable {
    let id: Int
    let ts: Date
    let appName: String?
    let windowTitle: String?
    let idleSecs: Double
    let isIdle: Bool
    let screenshotPath: String?
}

struct ScreenshotRecord: Identifiable {
    let id: Int
    let ts: Date
    let path: String
}

/// Aggregated data for a single calendar day.
struct DayActivity: Identifiable {
    let id: String         // "yyyy-MM-dd"
    let date: Date
    let activePolls: Int   // each poll = 5 s of tracked active time
    let idlePolls: Int
    let topApps: [String]  // up to 3 most-used

    var activeSeconds: TimeInterval { Double(activePolls) * 5 }
    var idleSeconds: TimeInterval   { Double(idlePolls)   * 5 }
    var totalSeconds: TimeInterval  { activeSeconds + idleSeconds }

    /// 0.0–1.0 intensity for the calendar heatmap (1.0 = 8-hour workday).
    var intensity: Double {
        min(Double(activePolls) / (8 * 3600 / 5), 1.0)
    }
}

/// A run of consecutive records for the same app — used in the timeline.
struct AppBlock: Identifiable {
    let id = UUID()
    let appName: String
    let start: Date
    var end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Per-app total for the day-detail bar chart.
struct AppTotal: Identifiable {
    let id: String    // app name
    let appName: String
    let duration: TimeInterval
}
