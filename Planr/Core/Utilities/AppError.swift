import Foundation

/// Shared error type. Messages are written for humans, not log files.
enum AppError: LocalizedError, Equatable {
    case permissionDenied(feature: String)
    case eventNotScheduled
    case eventNotFound
    case invalidInviteCode
    case uploadFailed
    case voteClosed
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let feature):
            return "Planr doesn't have permission for \(feature). You can change that in Settings."
        case .eventNotScheduled:
            return "Lock in a date first, then add it to your calendar."
        case .eventNotFound:
            return "That event has wandered off. Pull to refresh and try again."
        case .invalidInviteCode:
            return "That invite code doesn't look right. Ask the organiser for a fresh one."
        case .uploadFailed:
            return "That photo didn't make it. Give it another go."
        case .voteClosed:
            return "This vote has closed. The decision is in."
        case .persistenceFailed:
            return "Couldn't save your changes. Try again in a moment."
        }
    }
}

/// Standard screen-loading state used by views that do async work.
enum LoadingState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded(T)
    case empty
    case failed(AppError)
}
