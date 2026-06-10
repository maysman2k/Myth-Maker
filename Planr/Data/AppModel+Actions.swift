import Foundation

// MARK: - All state mutations. Every action persists the snapshot and,
// where it's a shared "moment", drops a system message into the event chat.

extension AppModel {

    // MARK: Onboarding & profile

    func completeOnboarding(profile: UserProfile, includeSampleEvent: Bool) {
        if includeSampleEvent {
            let snapshot = SeedFactory.sampleSnapshot(for: profile)
            people = snapshot.people
            events = snapshot.events
            votes = snapshot.votes
            tasks = snapshot.tasks
            payments = snapshot.payments
            messages = snapshot.messages
            photos = snapshot.photos
            bingoGames = snapshot.bingoGames
        } else {
            people = [profile]
        }
        currentUser = profile
        persist()
    }

    func updateProfile(_ profile: UserProfile) {
        currentUser = profile
        if let index = people.firstIndex(where: { $0.id == profile.id }) {
            people[index] = profile
        } else {
            people.append(profile)
        }
        persist()
    }

    /// Wipes everything except the signed-in profile.
    func resetAllData(keepProfile: Bool) {
        let me = keepProfile ? currentUser : nil
        for photo in photos {
            if let fileName = photo.fileName { imageStore.deleteImage(named: fileName) }
        }
        people = me.map { [$0] } ?? []
        currentUser = me
        events = []
        votes = []
        tasks = []
        payments = []
        messages = []
        photos = []
        bingoGames = []
        persist()
    }

    // MARK: Events

    @discardableResult
    func createEvent(title: String, detail: String, kind: EventKind,
                     startDate: Date?, endDate: Date?, locationName: String?,
                     privacy: PrivacyLevel, moodEmoji: String, budgetNote: String?,
                     coverPaletteIndex: Int, shameBoardEnabled: Bool) -> Event? {
        guard let me = currentUser else { return nil }
        let event = Event(title: title, detail: detail, kind: kind,
                          phase: .planning, leaderID: me.id,
                          participantIDs: [me.id],
                          startDate: startDate, endDate: endDate,
                          locationName: locationName?.isEmpty == true ? nil : locationName,
                          privacy: privacy,
                          coverPaletteIndex: coverPaletteIndex,
                          moodEmoji: moodEmoji,
                          budgetNote: budgetNote?.isEmpty == true ? nil : budgetNote,
                          shameBoardEnabled: shameBoardEnabled)
        events.append(event)
        post(system: "\(me.firstName) started planning \(event.title). Let the chaos end here.", in: event.id)
        haptics.success()
        persist()
        return event
    }

    func updateEvent(_ event: Event) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        var updated = event
        updated.updatedAt = .now
        events[index] = updated
        persist()
    }

    func deleteEvent(_ event: Event) {
        for photo in photos(for: event.id) {
            if let fileName = photo.fileName { imageStore.deleteImage(named: fileName) }
        }
        events.removeAll { $0.id == event.id }
        votes.removeAll { $0.eventID == event.id }
        tasks.removeAll { $0.eventID == event.id }
        payments.removeAll { $0.eventID == event.id }
        messages.removeAll { $0.eventID == event.id }
        photos.removeAll { $0.eventID == event.id }
        bingoGames.removeAll { $0.eventID == event.id }
        persist()
    }

    func leaveEvent(_ event: Event) {
        guard let me = currentUser, me.id != event.leaderID else { return }
        var updated = event
        updated.participantIDs.removeAll { $0 == me.id }
        updated.coLeaderIDs.removeAll { $0 == me.id }
        updateEvent(updated)
        post(system: "\(me.firstName) left the event.", in: event.id)
    }

    func regenerateInviteCode(for event: Event) {
        var updated = event
        updated.inviteCode = InviteCodeFactory.generate()
        updateEvent(updated)
    }

    /// Local-only join: matches codes for events already on this device.
    /// Real cross-device joining arrives with the sync backend.
    func joinEvent(code: String) -> Event? {
        guard let me = currentUser else { return nil }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let index = events.firstIndex(where: { $0.inviteCode == normalized }) else { return nil }
        if !events[index].participantIDs.contains(me.id) {
            events[index].participantIDs.append(me.id)
            post(system: "\(me.firstName) joined the event. 👋", in: events[index].id)
            persist()
        }
        return events[index]
    }

    // MARK: Lifecycle

    func lockdown(_ event: Event) {
        guard let me = currentUser, LockdownPolicy.canLockdown(event, userID: me.id) else { return }
        var updated = event
        updated.phase = .lockdown
        updated.lockedAt = .now
        updateEvent(updated)
        // Open votes are settled by lockdown; confirm the leaders' picks.
        for vote in votes(for: event.id) where vote.isOpen {
            if let leading = VoteCalculator.leadingTally(for: vote, participantCount: event.participantIDs.count) {
                confirm(vote: vote, winningOptionID: leading.option.id, announce: false)
            }
        }
        let fresh = self.event(withID: event.id) ?? updated
        post(system: "Locked in. No more chaos. \(DateUtilities.rangeLabel(start: fresh.startDate, end: fresh.endDate))\(fresh.locationName.map { " in \($0)" } ?? "").", in: event.id)
        notifications.scheduleEventReminder(for: fresh)
        haptics.lockdown()
        persist()
    }

    func startLiveMode(_ event: Event) {
        guard let me = currentUser, LockdownPolicy.canStartLiveMode(event, userID: me.id) else { return }
        var updated = event
        updated.phase = .live
        updateEvent(updated)
        post(system: "It's on. Have a good one — and feed the photo album. 📸", in: event.id)
        haptics.success()
    }

    func completeEvent(_ event: Event) {
        guard let me = currentUser, LockdownPolicy.canComplete(event, userID: me.id) else { return }
        var updated = event
        updated.phase = .completed
        updateEvent(updated)
        if var game = bingoGame(for: event.id), game.status == .playing {
            game.status = .finished
            game.winnerID = game.winnerID ?? BingoCardGenerator.winnerID(in: game.cards)
            upsert(game)
        }
        post(system: "Event wrapped. The memories are in the vault.", in: event.id)
        haptics.success()
        persist()
    }

    // MARK: Votes

    @discardableResult
    func createVote(eventID: String, title: String, detail: String?, kind: VoteKind,
                    options: [VoteOption], allowsMultipleSelection: Bool, deadline: Date?) -> Vote? {
        guard let me = currentUser, let event = event(withID: eventID) else { return nil }
        let vote = Vote(eventID: eventID, createdByID: me.id, title: title, detail: detail,
                        kind: kind, options: options,
                        allowsMultipleSelection: allowsMultipleSelection, deadline: deadline)
        votes.append(vote)
        post(system: "\(me.firstName) opened a vote: \(title)", in: eventID)
        if let deadline, deadline > .now {
            notifications.scheduleVoteDeadline(for: vote, eventTitle: event.title)
        }
        persist()
        return vote
    }

    func respond(to vote: Vote, optionIDs: [String]) {
        guard let me = currentUser, vote.isOpen,
              let index = votes.firstIndex(where: { $0.id == vote.id }) else { return }
        votes[index].responses.removeAll { $0.userID == me.id }
        if !optionIDs.isEmpty {
            votes[index].responses.append(VoteResponse(userID: me.id, optionIDs: optionIDs))
        }
        haptics.tap()
        persist()
    }

    func confirm(vote: Vote, winningOptionID: String, announce: Bool = true) {
        guard let index = votes.firstIndex(where: { $0.id == vote.id }),
              let event = event(withID: vote.eventID),
              let winner = vote.options.first(where: { $0.id == winningOptionID }) else { return }
        votes[index].status = .confirmed
        votes[index].winningOptionID = winningOptionID

        // Confirmed date/location votes flow straight into the event details.
        var updated = event
        switch vote.kind {
        case .dateAvailability:
            if let date = winner.date {
                updated.startDate = date
                if (updated.endDate ?? .distantPast) < date {
                    updated.endDate = date
                }
            }
        case .location:
            updated.locationName = winner.label
        case .freeform:
            break
        }
        updateEvent(updated)

        if announce, let me = currentUser {
            post(system: "\(me.firstName) locked in \(winner.label) for \"\(vote.title)\".", in: vote.eventID)
        }
        notifications.cancelReminders(withIDs: ["vote-deadline-\(vote.id)"])
        haptics.success()
        persist()
    }

    // MARK: Tasks

    func addTask(eventID: String, title: String, detail: String?, assigneeID: String, dueDate: Date?) {
        guard let me = currentUser else { return }
        let task = EventTask(eventID: eventID, title: title, detail: detail,
                             assigneeID: assigneeID, createdByID: me.id, dueDate: dueDate)
        tasks.append(task)
        if assigneeID != me.id {
            post(system: "\(displayName(for: assigneeID)) is on the hook for: \(title)", in: eventID)
        }
        persist()
    }

    func setTaskStatus(_ task: EventTask, to status: TaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = status
        tasks[index].completedAt = status == .complete ? .now : nil
        if status == .complete {
            post(system: "\(displayName(for: task.assigneeID)) finished the task: \(task.title).", in: task.eventID)
            haptics.success()
        }
        persist()
    }

    func deleteTask(_ task: EventTask) {
        tasks.removeAll { $0.id == task.id }
        persist()
    }

    // MARK: Payments

    func addPayment(eventID: String, title: String, amountPerPerson: Decimal,
                    owedByIDs: [String], dueDate: Date?) {
        guard let me = currentUser else { return }
        let payment = Payment(eventID: eventID, title: title, amountPerPerson: amountPerPerson,
                              paidByID: me.id,
                              shares: owedByIDs.map { PaymentShare(userID: $0) },
                              dueDate: dueDate)
        payments.append(payment)
        post(system: "New payment to settle: \(title) — \(payment.formattedAmount) each to \(me.firstName).", in: eventID)
        persist()
    }

    func markShare(of payment: Payment, userID: String, as state: PaymentShareState) {
        guard let paymentIndex = payments.firstIndex(where: { $0.id == payment.id }),
              let shareIndex = payments[paymentIndex].shares.firstIndex(where: { $0.userID == userID }) else { return }
        payments[paymentIndex].shares[shareIndex].state = state
        switch state {
        case .markedPaid:
            payments[paymentIndex].shares[shareIndex].markedPaidAt = .now
        case .confirmed:
            payments[paymentIndex].shares[shareIndex].confirmedAt = .now
            post(system: "\(displayName(for: userID)) is all paid up for \(payment.title). 💸", in: payment.eventID)
        case .owed:
            payments[paymentIndex].shares[shareIndex].markedPaidAt = nil
            payments[paymentIndex].shares[shareIndex].confirmedAt = nil
        }
        haptics.success()
        persist()
    }

    // MARK: Chat

    func sendMessage(_ text: String, in eventID: String) {
        guard let me = currentUser else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(eventID: eventID, senderID: me.id, text: trimmed))
        persist()
    }

    func post(system text: String, in eventID: String) {
        messages.append(ChatMessage(eventID: eventID, senderID: nil, kind: .system, text: text))
    }

    func toggleReaction(_ emoji: String, on message: ChatMessage) {
        guard let me = currentUser,
              let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        var reactors = messages[index].reactions[emoji] ?? []
        if let existing = reactors.firstIndex(of: me.id) {
            reactors.remove(at: existing)
        } else {
            reactors.append(me.id)
            haptics.tap()
        }
        messages[index].reactions[emoji] = reactors.isEmpty ? nil : reactors
        persist()
    }

    // MARK: Photos

    func importPhotos(_ imageDatas: [Data], to eventID: String) {
        guard let me = currentUser else { return }
        for data in imageDatas {
            let id = UUID().uuidString
            guard let fileName = try? imageStore.saveJPEG(data, id: id) else { continue }
            photos.append(EventPhoto(id: id, eventID: eventID, uploaderID: me.id, fileName: fileName))
        }
        haptics.success()
        persist()
    }

    func setCaption(_ caption: String, on photo: EventPhoto) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        photos[index].caption = caption.isEmpty ? nil : caption
        persist()
    }

    func toggleReaction(_ emoji: String, on photo: EventPhoto) {
        guard let me = currentUser,
              let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        var reactors = photos[index].reactions[emoji] ?? []
        if let existing = reactors.firstIndex(of: me.id) {
            reactors.remove(at: existing)
        } else {
            reactors.append(me.id)
            haptics.tap()
        }
        photos[index].reactions[emoji] = reactors.isEmpty ? nil : reactors
        persist()
    }

    /// Owners can delete their own photos; leaders can moderate any.
    func canDelete(_ photo: EventPhoto) -> Bool {
        guard let me = currentUser, let event = event(withID: photo.eventID) else { return false }
        return photo.uploaderID == me.id || event.role(of: me.id).canManage
    }

    func deletePhoto(_ photo: EventPhoto) {
        guard canDelete(photo) else { return }
        if let fileName = photo.fileName { imageStore.deleteImage(named: fileName) }
        photos.removeAll { $0.id == photo.id }
        persist()
    }

    // MARK: Bingo

    private func upsert(_ game: BingoGame) {
        if let index = bingoGames.firstIndex(where: { $0.id == game.id }) {
            bingoGames[index] = game
        } else {
            bingoGames.append(game)
        }
        persist()
    }

    func startBingo(for eventID: String) {
        guard bingoGame(for: eventID) == nil else { return }
        upsert(BingoGame(eventID: eventID))
        post(system: "Event Bingo is open. Submit your predictions. 🎯", in: eventID)
        persist()
    }

    func submitBingoPrediction(_ text: String, eventID: String) {
        guard let me = currentUser, var game = bingoGame(for: eventID),
              game.status == .collecting else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        game.submissions.append(BingoSubmission(authorID: me.id, text: trimmed))
        upsert(game)
    }

    func setBingoSubmissionApproved(_ submission: BingoSubmission, eventID: String, approved: Bool) {
        guard var game = bingoGame(for: eventID),
              let index = game.submissions.firstIndex(where: { $0.id == submission.id }) else { return }
        game.submissions[index].approved = approved
        upsert(game)
    }

    func dealBingoCards(for event: Event) {
        guard var game = bingoGame(for: event.id), game.status == .collecting else { return }
        let cards = BingoCardGenerator.deal(submissions: game.submissions,
                                            to: event.participantIDs)
        guard !cards.isEmpty else { return }
        game.cards = cards
        game.status = .playing
        upsert(game)
        post(system: "Bingo cards are out. First full card wins. 👀", in: event.id)
        haptics.success()
        persist()
    }

    func claimBingoSquare(_ square: BingoSquare, eventID: String) {
        guard let me = currentUser, var game = bingoGame(for: eventID),
              let cardIndex = game.cards.firstIndex(where: { $0.ownerID == me.id }),
              let squareIndex = game.cards[cardIndex].squares.firstIndex(where: { $0.id == square.id }) else { return }
        game.cards[cardIndex].squares[squareIndex].claimedByID = me.id
        upsert(game)
        haptics.tap()
    }

    func resolveBingoClaim(cardOwnerID: String, square: BingoSquare, eventID: String, approve: Bool) {
        guard var game = bingoGame(for: eventID),
              let cardIndex = game.cards.firstIndex(where: { $0.ownerID == cardOwnerID }),
              let squareIndex = game.cards[cardIndex].squares.firstIndex(where: { $0.id == square.id }) else { return }
        if approve {
            game.cards[cardIndex].squares[squareIndex].confirmed = true
            if let text = game.submission(withID: square.submissionID)?.text {
                post(system: "Bingo claim approved: \(text).", in: eventID)
            }
            if game.cards[cardIndex].isComplete {
                game.status = .finished
                game.winnerID = cardOwnerID
                post(system: "BINGO! \(displayName(for: cardOwnerID)) has the full card. 🏆", in: eventID)
                haptics.success()
            }
        } else {
            game.cards[cardIndex].squares[squareIndex].claimedByID = nil
        }
        upsert(game)
        persist()
    }
}
