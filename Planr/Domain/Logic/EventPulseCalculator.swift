import Foundation

/// Event Pulse: a single readiness score for the event, with a breakdown
/// the dashboard can show. Pure function of the event's current data.
enum EventPulseCalculator {

    struct Component: Identifiable, Equatable {
        let title: String
        let symbol: String
        /// 0...1 completeness of this slice.
        let progress: Double
        let weight: Double

        var id: String { title }
    }

    struct Pulse: Equatable {
        let score: Int            // 0...100
        let components: [Component]
    }

    static func calculate(event: Event,
                          votes: [Vote],
                          tasks: [EventTask],
                          payments: [Payment],
                          participantCount: Int) -> Pulse {
        // Decisions: confirmed votes plus whether the big two (date, location) exist.
        let voteProgress: Double = votes.isEmpty
            ? 1
            : Double(votes.filter { $0.status == .confirmed }.count) / Double(votes.count)
        let basicsProgress = ((event.startDate != nil ? 0.5 : 0) + (event.locationName != nil ? 0.5 : 0))
        let decisions = Component(title: "Decisions",
                                  symbol: "checkmark.seal",
                                  progress: (voteProgress + basicsProgress) / 2,
                                  weight: 0.35)

        let taskProgress: Double = tasks.isEmpty
            ? 1
            : Double(tasks.filter { $0.status == .complete }.count) / Double(tasks.count)
        let taskComponent = Component(title: "Tasks",
                                      symbol: "checklist",
                                      progress: taskProgress,
                                      weight: 0.25)

        let allShares = payments.flatMap(\.shares)
        let paymentProgress: Double = allShares.isEmpty
            ? 1
            : Double(allShares.filter { $0.state == .confirmed }.count) / Double(allShares.count)
        let paymentComponent = Component(title: "Money",
                                         symbol: "sterlingsign.circle",
                                         progress: paymentProgress,
                                         weight: 0.25)

        let engagement: Double = votes.isEmpty
            ? 1
            : votes.map { VoteCalculator.responseRate(for: $0, participantCount: participantCount) }
                .reduce(0, +) / Double(votes.count)
        let engagementComponent = Component(title: "Replies",
                                            symbol: "person.2.wave.2",
                                            progress: engagement,
                                            weight: 0.15)

        let components = [decisions, taskComponent, paymentComponent, engagementComponent]
        let weighted = components.reduce(0) { $0 + $1.progress * $1.weight }
        return Pulse(score: Int((weighted * 100).rounded()), components: components)
    }

    /// Friendly one-liner for the dashboard card. `blockerName` is the person
    /// with the most outstanding items, if there is a clear one.
    static func headline(for pulse: Pulse, blockerName: String? = nil) -> String {
        switch pulse.score {
        case 95...:
            return "Locked and loaded. Bring it on."
        case 75..<95:
            if let blockerName {
                return "Nearly there. \(blockerName) is the only thing standing between this and glory."
            }
            return "Nearly there. A few loose ends to tie up."
        case 40..<75:
            return "Solid progress, but the plan needs a push."
        default:
            return "Early days. Time to make some decisions."
        }
    }
}
