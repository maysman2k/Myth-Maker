import Foundation

/// Builds the post-event wrap: stats, awards and highlights.
/// Pure function of the event's data so it can be regenerated any time.
enum EventWrapBuilder {

    struct Stat: Identifiable, Equatable {
        let title: String
        let value: String
        let symbol: String

        var id: String { title }
    }

    struct Award: Identifiable, Equatable {
        let title: String
        let emoji: String
        let userID: String
        let reason: String

        var id: String { title }
    }

    struct Wrap: Equatable {
        let stats: [Stat]
        let awards: [Award]
        /// Most-reacted photo, if any.
        let topPhotoID: String?
        /// Most-reacted chat message, if any.
        let topMessageID: String?
        let bingoWinnerID: String?
    }

    static func build(event: Event,
                      participants: [UserProfile],
                      votes: [Vote],
                      tasks: [EventTask],
                      payments: [Payment],
                      messages: [ChatMessage],
                      photos: [EventPhoto],
                      bingo: BingoGame?) -> Wrap {
        var stats: [Stat] = [
            Stat(title: "Crew", value: "\(participants.count)", symbol: "person.3.fill"),
            Stat(title: "Photos", value: "\(photos.count)", symbol: "photo.on.rectangle.angled"),
            Stat(title: "Messages", value: "\(messages.filter { $0.kind == .text }.count)", symbol: "bubble.left.and.bubble.right.fill"),
            Stat(title: "Decisions made", value: "\(votes.filter { $0.status == .confirmed }.count)", symbol: "checkmark.seal.fill"),
        ]
        if let start = event.startDate {
            let planningDays = max(0, DateUtilities.daysUntil(start, from: event.createdAt))
            stats.append(Stat(title: "Days in the making", value: "\(planningDays)", symbol: "calendar"))
        }

        var awards: [Award] = []
        func name(_ id: String) -> String {
            participants.first { $0.id == id }?.firstName ?? "Someone"
        }

        // Event MVP: most completed tasks.
        let taskCounts = counts(tasks.filter { $0.status == .complete }.map(\.assigneeID))
        if let mvp = taskCounts.max(by: { $0.value < $1.value }), mvp.value > 0 {
            awards.append(Award(title: "Event MVP", emoji: "🏆", userID: mvp.key,
                                reason: "\(name(mvp.key)) carried the plan with \(mvp.value) tasks done."))
        }

        // Chat champion: most messages sent.
        let chatCounts = counts(messages.filter { $0.kind == .text }.compactMap(\.senderID))
        if let champ = chatCounts.max(by: { $0.value < $1.value }), champ.value > 0 {
            awards.append(Award(title: "Chat champion", emoji: "🗣️", userID: champ.key,
                                reason: "\(name(champ.key)) sent \(champ.value) messages. Impressive thumbs."))
        }

        // Shutterbug: most photos uploaded.
        let photoCounts = counts(photos.map(\.uploaderID))
        if let snapper = photoCounts.max(by: { $0.value < $1.value }), snapper.value > 0 {
            awards.append(Award(title: "Shutterbug", emoji: "📸", userID: snapper.key,
                                reason: "\(name(snapper.key)) captured \(snapper.value) moments."))
        }

        // Last to pay: latest settle-up date.
        let settleDates = payments.flatMap(\.shares).compactMap { share -> (String, Date)? in
            guard let date = share.confirmedAt ?? share.markedPaidAt else { return nil }
            return (share.userID, date)
        }
        if settleDates.count > 1, let last = settleDates.max(by: { $0.1 < $1.1 }) {
            awards.append(Award(title: "Last to pay", emoji: "🐢", userID: last.0,
                                reason: "\(name(last.0)) got there. Eventually. Naturally."))
        }

        if let bingo, let winnerID = bingo.winnerID {
            awards.append(Award(title: "Bingo champion", emoji: "🎯", userID: winnerID,
                                reason: "\(name(winnerID)) called it. Five out of five."))
        }

        let topPhoto = photos.max { $0.reactionCount < $1.reactionCount }
        let topMessage = messages.filter { $0.kind == .text }.max { $0.reactionCount < $1.reactionCount }

        return Wrap(stats: stats,
                    awards: awards,
                    topPhotoID: (topPhoto?.reactionCount ?? 0) > 0 ? topPhoto?.id : nil,
                    topMessageID: (topMessage?.reactionCount ?? 0) > 0 ? topMessage?.id : nil,
                    bingoWinnerID: bingo?.winnerID)
    }

    private static func counts(_ ids: [String]) -> [String: Int] {
        ids.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }
}
