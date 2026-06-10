import Foundation

/// Pure vote maths: tallies, winners, consensus levels, response rates.
enum VoteCalculator {

    struct Tally: Equatable {
        let option: VoteOption
        let count: Int
        let voterIDs: [String]
        /// Fraction of all event participants who picked this option.
        let share: Double
    }

    enum Consensus: Equatable {
        case unanimous      // everyone picked it
        case strongMajority // 70%+
        case bestAvailable  // leading but not strong
        case none
    }

    /// Tallies sorted by count (desc), ties broken by original option order
    /// so results are stable.
    static func tallies(for vote: Vote, participantCount: Int) -> [Tally] {
        let tallies = vote.options.map { option in
            let voters = vote.responses
                .filter { $0.optionIDs.contains(option.id) }
                .map(\.userID)
            return Tally(option: option,
                         count: voters.count,
                         voterIDs: voters,
                         share: participantCount > 0 ? Double(voters.count) / Double(participantCount) : 0)
        }
        let order = Dictionary(uniqueKeysWithValues: vote.options.enumerated().map { ($1.id, $0) })
        return tallies.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return (order[$0.option.id] ?? 0) < (order[$1.option.id] ?? 0)
        }
    }

    /// The option currently in the lead, or nil if nobody has voted yet.
    static func leadingTally(for vote: Vote, participantCount: Int) -> Tally? {
        let sorted = tallies(for: vote, participantCount: participantCount)
        guard let first = sorted.first, first.count > 0 else { return nil }
        return first
    }

    static func consensus(count: Int, participantCount: Int) -> Consensus {
        guard participantCount > 0, count > 0 else { return .none }
        let share = Double(count) / Double(participantCount)
        if count == participantCount { return .unanimous }
        if share >= 0.7 { return .strongMajority }
        return .bestAvailable
    }

    /// Fraction of participants who have responded to this vote.
    static func responseRate(for vote: Vote, participantCount: Int) -> Double {
        guard participantCount > 0 else { return 0 }
        let responders = Set(vote.responses.map(\.userID)).count
        return min(1, Double(responders) / Double(participantCount))
    }

    static func nonResponders(for vote: Vote, participantIDs: [String]) -> [String] {
        let responded = Set(vote.responses.map(\.userID))
        return participantIDs.filter { !responded.contains($0) }
    }
}
