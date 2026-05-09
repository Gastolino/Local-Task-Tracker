import Foundation

// MARK: - Project

struct Project: Identifiable, Hashable {
    let id: Int
    var name: String
    var color: String          // hex, e.g. "#5856D6"
    var description: String?
    let createdAt: Date
    var isArchived: Bool
    var deadline: Date?
    var allocatedHours: Double?
    var iconEmoji: String?
    var iconColor: String?     // hex for emoji background; nil = use project color
    var iconImagePath: String? // absolute path to copied image file

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

// MARK: - Invoice

enum InvoiceStatus: String, CaseIterable {
    case draft          = "draft"
    case sent           = "sent"
    case pendingPayment = "pending_payment"
    case paid           = "paid"
    case cancelled      = "cancelled"

    var label: String {
        switch self {
        case .draft:          return "Draft"
        case .sent:           return "Sent"
        case .pendingPayment: return "Pending"
        case .paid:           return "Paid"
        case .cancelled:      return "Cancelled"
        }
    }
}

struct Invoice: Identifiable {
    let id: Int
    let projectID: Int
    var projectName: String
    var projectColor: String
    var number: String
    var amount: Double
    var currency: String
    var status: InvoiceStatus
    var issuedDate: Date
    var dueDate: Date?
    var notes: String?
    var filePath: String?      // attached PDF or document
    let createdAt: Date

    var isOverdue: Bool {
        guard let due = dueDate else { return false }
        return status != .paid && status != .cancelled && due < Date()
    }
}

// MARK: - Offer

struct Offer: Identifiable {
    let id: Int
    let projectID: Int
    var projectName: String
    var projectColor: String
    var title: String
    var amount: Double?
    var currency: String
    var filePath: String?
    let createdAt: Date
}
