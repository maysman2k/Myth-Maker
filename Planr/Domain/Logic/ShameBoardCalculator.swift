import Foundation

/// The opt-in accountability board. Playful, never punishing:
/// it celebrates heroes as loudly as it teases stragglers, and anyone
/// who opted out in their safety settings is excluded entirely.
enum ShameBoardCalculator {

    struct Entry: Identifiable, Equatable {
        let title: String
        let emoji: String
        let userID: String
        let detail: String

        var id: String { title }
    }

    static func entries(participants: [UserProfile],
                        tasks: [EventTask],
                        payments: [Payment],
                        now: Date = .now) -> [Entry] {
        let visible = participants.filter { !$0.hiddenFromShameBoard }
        guard !visible.isEmpty else { return [] }
        var entries: [Entry] = []

        // Fastest payer — earliest settle-up across all payments.
        let settled = payments.flatMap(\.shares)
            .compactMap { share -> (String, Date)? in
                guard let date = share.markedPaidAt ?? share.confirmedAt else { return nil }
                return (share.userID, date)
            }
            .filter { pair in visible.contains { $0.id == pair.0 } }
        if let fastest = settled.min(by: { $0.1 < $1.1 }),
           let user = visible.first(where: { $0.id == fastest.0 }) {
            entries.append(Entry(title: "Fastest payer", emoji: "⚡️", userID: user.id,
                                 detail: "\(user.firstName) settled up before anyone blinked."))
        }

        // Still owes — most outstanding shares.
        let owedCounts = countBy(payments.flatMap(\.shares).filter { $0.state == .owed }.map(\.userID),
                                 visible: visible)
        if let worst = owedCounts.max(by: { $0.value < $1.value }), worst.value > 0,
           let user = visible.first(where: { $0.id == worst.key }) {
            entries.append(Entry(title: "Wallet in witness protection", emoji: "💸", userID: user.id,
                                 detail: "\(user.firstName) still owes for \(worst.value) thing\(worst.value == 1 ? "" : "s")."))
        }

        // Task hero — most completed tasks.
        let heroCounts = countBy(tasks.filter { $0.status == .complete }.map(\.assigneeID), visible: visible)
        if let hero = heroCounts.max(by: { $0.value < $1.value }), hero.value > 0,
           let user = visible.first(where: { $0.id == hero.key }) {
            entries.append(Entry(title: "Event hero", emoji: "🦸", userID: user.id,
                                 detail: "\(user.firstName) has knocked out \(hero.value) task\(hero.value == 1 ? "" : "s")."))
        }

        // Overdue — most overdue tasks.
        let overdueCounts = countBy(tasks.filter { $0.isOverdue(now: now) }.map(\.assigneeID), visible: visible)
        if let slacker = overdueCounts.max(by: { $0.value < $1.value }), slacker.value > 0,
           let user = visible.first(where: { $0.id == slacker.key }) {
            entries.append(Entry(title: "Fashionably late", emoji: "🐌", userID: user.id,
                                 detail: "\(user.firstName) has \(slacker.value) overdue task\(slacker.value == 1 ? "" : "s")."))
        }

        return entries
    }

    private static func countBy(_ userIDs: [String], visible: [UserProfile]) -> [String: Int] {
        let visibleIDs = Set(visible.map(\.id))
        return userIDs.filter(visibleIDs.contains).reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }
}
