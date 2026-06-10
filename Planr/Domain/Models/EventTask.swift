import Foundation

enum TaskStatus: String, Codable, CaseIterable {
    case open
    case inProgress
    case complete

    var label: String {
        switch self {
        case .open: return "To do"
        case .inProgress: return "On it"
        case .complete: return "Done"
        }
    }

    var symbol: String {
        switch self {
        case .open: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

struct EventTask: Identifiable, Codable, Hashable {
    var id: String
    var eventID: String
    var title: String
    var detail: String?
    var assigneeID: String
    var createdByID: String
    var status: TaskStatus
    var dueDate: Date?
    var completedAt: Date?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         eventID: String,
         title: String,
         detail: String? = nil,
         assigneeID: String,
         createdByID: String,
         status: TaskStatus = .open,
         dueDate: Date? = nil,
         completedAt: Date? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.eventID = eventID
        self.title = title
        self.detail = detail
        self.assigneeID = assigneeID
        self.createdByID = createdByID
        self.status = status
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    func isOverdue(now: Date = .now) -> Bool {
        guard let dueDate, status != .complete else { return false }
        return dueDate < now
    }
}
