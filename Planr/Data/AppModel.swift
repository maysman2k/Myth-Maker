import Foundation
import Observation

/// Single source of truth for app state. Views observe it; mutations go
/// through the action methods in `AppModel+Actions.swift`, which keep the
/// snapshot persisted and post system chat messages for key moments.
@MainActor
@Observable
final class AppModel {

    // MARK: State

    var currentUser: UserProfile?
    var people: [UserProfile] = []
    var events: [Event] = []
    var votes: [Vote] = []
    var tasks: [EventTask] = []
    var payments: [Payment] = []
    var messages: [ChatMessage] = []
    var photos: [EventPhoto] = []
    var bingoGames: [BingoGame] = []

    // MARK: Services

    @ObservationIgnored let store: SnapshotPersisting
    @ObservationIgnored let imageStore = ImageStore()
    @ObservationIgnored let haptics = HapticsService()
    @ObservationIgnored let calendarSync: CalendarSyncing = EventKitCalendarService()
    @ObservationIgnored let notifications = NotificationScheduler()

    init(store: SnapshotPersisting = LocalStore()) {
        self.store = store
        if let snapshot = store.load() {
            apply(snapshot)
        }
    }

    private func apply(_ snapshot: AppSnapshot) {
        people = snapshot.people
        currentUser = snapshot.people.first { $0.id == snapshot.currentUserID }
        events = snapshot.events
        votes = snapshot.votes
        tasks = snapshot.tasks
        payments = snapshot.payments
        messages = snapshot.messages
        photos = snapshot.photos
        bingoGames = snapshot.bingoGames
    }

    func persist() {
        var snapshot = AppSnapshot()
        snapshot.currentUserID = currentUser?.id
        snapshot.people = people
        snapshot.events = events
        snapshot.votes = votes
        snapshot.tasks = tasks
        snapshot.payments = payments
        snapshot.messages = messages
        snapshot.photos = photos
        snapshot.bingoGames = bingoGames
        store.save(snapshot)
    }

    // MARK: Lookups

    func event(withID id: String) -> Event? {
        events.first { $0.id == id }
    }

    func user(withID id: String) -> UserProfile? {
        people.first { $0.id == id }
    }

    func displayName(for id: String?) -> String {
        guard let id else { return "Planr" }
        return user(withID: id)?.firstName ?? "Someone"
    }

    func participants(in event: Event) -> [UserProfile] {
        event.participantIDs.compactMap { user(withID: $0) }
    }

    func isLeader(of event: Event) -> Bool {
        currentUser?.id == event.leaderID
    }

    func role(in event: Event) -> EventRole {
        guard let currentUser else { return .participant }
        return event.role(of: currentUser.id)
    }

    func votes(for eventID: String) -> [Vote] {
        votes.filter { $0.eventID == eventID }
            .sorted { ($0.isOpen ? 0 : 1, $0.createdAt) < ($1.isOpen ? 0 : 1, $1.createdAt) }
    }

    func tasks(for eventID: String) -> [EventTask] {
        tasks.filter { $0.eventID == eventID }
            .sorted { ($0.status == .complete ? 1 : 0, $0.createdAt) < ($1.status == .complete ? 1 : 0, $1.createdAt) }
    }

    func payments(for eventID: String) -> [Payment] {
        payments.filter { $0.eventID == eventID }.sorted { $0.createdAt < $1.createdAt }
    }

    func messages(for eventID: String) -> [ChatMessage] {
        messages.filter { $0.eventID == eventID }.sorted { $0.createdAt < $1.createdAt }
    }

    func photos(for eventID: String) -> [EventPhoto] {
        photos.filter { $0.eventID == eventID }.sorted { $0.createdAt > $1.createdAt }
    }

    func bingoGame(for eventID: String) -> BingoGame? {
        bingoGames.first { $0.eventID == eventID }
    }

    // MARK: Derived collections

    var upcomingEvents: [Event] {
        events.filter { !$0.isFinished }
            .sorted { ($0.startDate ?? .distantFuture, $0.createdAt) < ($1.startDate ?? .distantFuture, $1.createdAt) }
    }

    var completedEvents: [Event] {
        events.filter(\.isFinished)
            .sorted { ($0.startDate ?? $0.createdAt) > ($1.startDate ?? $1.createdAt) }
    }

    func pulse(for event: Event) -> EventPulseCalculator.Pulse {
        EventPulseCalculator.calculate(event: event,
                                       votes: votes(for: event.id),
                                       tasks: tasks(for: event.id),
                                       payments: payments(for: event.id),
                                       participantCount: event.participantIDs.count)
    }

    /// The participant with the most outstanding items, used for the
    /// Event Pulse headline. Only named when there's a single clear blocker.
    func blockerName(for event: Event) -> String? {
        var outstanding: [String: Int] = [:]
        for vote in votes(for: event.id) where vote.isOpen {
            for id in VoteCalculator.nonResponders(for: vote, participantIDs: event.participantIDs) {
                outstanding[id, default: 0] += 1
            }
        }
        for task in tasks(for: event.id) where task.status != .complete {
            outstanding[task.assigneeID, default: 0] += 1
        }
        for payment in payments(for: event.id) {
            for share in payment.shares where share.state == .owed {
                outstanding[share.userID, default: 0] += 1
            }
        }
        let sorted = outstanding.sorted { $0.value > $1.value }
        guard let top = sorted.first, top.value > 0,
              sorted.dropFirst().first?.value ?? 0 < top.value else { return nil }
        return user(withID: top.key)?.firstName
    }

    // MARK: Pending actions for Home

    struct PendingAction: Identifiable {
        enum Kind { case vote, task, payment }
        let id: String
        let kind: Kind
        let eventID: String
        let title: String
        let eventTitle: String
        let symbol: String
    }

    var pendingActions: [PendingAction] {
        guard let me = currentUser else { return [] }
        var actions: [PendingAction] = []
        for event in upcomingEvents {
            for vote in votes(for: event.id) where vote.isOpen && vote.response(from: me.id) == nil {
                actions.append(PendingAction(id: "vote-\(vote.id)", kind: .vote, eventID: event.id,
                                             title: "Vote: \(vote.title)", eventTitle: event.title,
                                             symbol: "hand.raised.fill"))
            }
            for task in tasks(for: event.id) where task.assigneeID == me.id && task.status != .complete {
                actions.append(PendingAction(id: "task-\(task.id)", kind: .task, eventID: event.id,
                                             title: task.title, eventTitle: event.title,
                                             symbol: task.isOverdue() ? "exclamationmark.circle.fill" : "checklist"))
            }
            for payment in payments(for: event.id) {
                if let share = payment.share(for: me.id), share.state == .owed {
                    actions.append(PendingAction(id: "pay-\(payment.id)", kind: .payment, eventID: event.id,
                                                 title: "You owe \(payment.formattedAmount) — \(payment.title)",
                                                 eventTitle: event.title,
                                                 symbol: "sterlingsign.circle.fill"))
                }
            }
        }
        return actions
    }
}
