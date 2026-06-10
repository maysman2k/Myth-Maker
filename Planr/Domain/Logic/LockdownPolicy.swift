import Foundation

/// Rules for who can change what, and when an event can be locked down.
enum LockdownPolicy {

    /// Core details = date, location, main plan.
    static func canEditCoreDetails(of event: Event, userID: String) -> Bool {
        guard !event.isFinished else { return false }
        if event.isLockedDown {
            // After lockdown only the leader can override; everyone else
            // needs a reopen vote.
            return userID == event.leaderID
        }
        return event.role(of: userID).canManage
    }

    /// Lockdown needs a leader and at least a confirmed date.
    static func canLockdown(_ event: Event, userID: String) -> Bool {
        event.phase == .planning
            && userID == event.leaderID
            && event.startDate != nil
    }

    static func canStartLiveMode(_ event: Event, userID: String, now: Date = .now) -> Bool {
        guard event.role(of: userID).canManage,
              event.phase == .lockdown || event.phase == .detailedPlanning else { return false }
        // Leaders can go live manually from the day before the event.
        if let start = event.startDate {
            return DateUtilities.daysUntil(start, from: now) <= 1
        }
        return false
    }

    static func canComplete(_ event: Event, userID: String) -> Bool {
        event.phase == .live && userID == event.leaderID
    }

    /// Changing a locked decision without leader override requires a reopen vote.
    static func requiresReopenVote(event: Event, userID: String) -> Bool {
        event.isLockedDown && userID != event.leaderID
    }
}
