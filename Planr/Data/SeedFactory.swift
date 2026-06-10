import Foundation

/// Builds the optional sample data offered at the end of onboarding,
/// so the first run shows the product at its best instead of empty screens.
enum SeedFactory {

    // swiftlint:disable:next function_body_length
    static func sampleSnapshot(for user: UserProfile) -> AppSnapshot {
        let pete = UserProfile(displayName: "Pete Donnelly", avatarSymbol: "crown.fill", avatarColorIndex: 1)
        let gary = UserProfile(displayName: "Gary Mills", avatarSymbol: "bolt.fill", avatarColorIndex: 3)
        let dave = UserProfile(displayName: "Dave Hutton", avatarSymbol: "gamecontroller.fill", avatarColorIndex: 2)
        let sarah = UserProfile(displayName: "Sarah Quinn", avatarSymbol: "star.fill", avatarColorIndex: 4)
        let mia = UserProfile(displayName: "Mia Carter", avatarSymbol: "music.note", avatarColorIndex: 5)
        let friends = [pete, gary, dave, sarah, mia]

        let calendar = Calendar.current
        let now = Date.now
        func daysFromNow(_ days: Int, hour: Int = 18) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        }
        /// Next Saturday at least `weeks` weeks away.
        func saturday(inWeeks weeks: Int) -> Date {
            var date = calendar.date(byAdding: .weekOfYear, value: weeks, to: now)!
            while calendar.component(.weekday, from: date) != 7 {
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
            return calendar.startOfDay(for: date)
        }

        var snapshot = AppSnapshot()
        snapshot.currentUserID = user.id
        snapshot.people = [user] + friends

        // MARK: Dublin Weekend — mid-planning, the user is the leader.

        let dublinCrew = [user.id, pete.id, gary.id, dave.id, sarah.id]
        let dublin = Event(title: "Dublin Weekend",
                           detail: "Weekend away with the gang. Pints, sea air and questionable decisions.",
                           kind: .weekendTrip,
                           phase: .planning,
                           leaderID: user.id,
                           coLeaderIDs: [pete.id],
                           participantIDs: dublinCrew,
                           locationName: "Dublin",
                           coverPaletteIndex: 2,
                           moodEmoji: "🍀",
                           budgetNote: "Around £250 each all-in",
                           shameBoardEnabled: true,
                           createdAt: daysFromNow(-12))

        let dateOptions = (5...7).map { weeks -> VoteOption in
            let day = saturday(inWeeks: weeks)
            return VoteOption(label: DateUtilities.shortDay(day), date: day)
        }
        let dateVote = Vote(eventID: dublin.id,
                            createdByID: user.id,
                            title: "Which weekend works?",
                            detail: "Tap every Saturday you can make.",
                            kind: .dateAvailability,
                            options: dateOptions,
                            deadline: daysFromNow(4, hour: 20),
                            responses: [
                                VoteResponse(userID: pete.id, optionIDs: [dateOptions[0].id, dateOptions[1].id]),
                                VoteResponse(userID: gary.id, optionIDs: [dateOptions[1].id]),
                                VoteResponse(userID: dave.id, optionIDs: [dateOptions[1].id, dateOptions[2].id]),
                                VoteResponse(userID: sarah.id, optionIDs: [dateOptions[0].id, dateOptions[1].id]),
                            ])

        let destinationOptions = [VoteOption(label: "Dublin", subtitle: "Flights from £60"),
                                  VoteOption(label: "Liverpool", subtitle: "Trains every hour"),
                                  VoteOption(label: "Edinburgh", subtitle: "Fringe season!")]
        let destinationVote = Vote(eventID: dublin.id,
                                   createdByID: pete.id,
                                   title: "Where are we going?",
                                   kind: .location,
                                   options: destinationOptions,
                                   status: .confirmed,
                                   winningOptionID: destinationOptions[0].id,
                                   responses: [
                                       VoteResponse(userID: user.id, optionIDs: [destinationOptions[0].id]),
                                       VoteResponse(userID: pete.id, optionIDs: [destinationOptions[0].id]),
                                       VoteResponse(userID: gary.id, optionIDs: [destinationOptions[1].id]),
                                       VoteResponse(userID: dave.id, optionIDs: [destinationOptions[0].id]),
                                       VoteResponse(userID: sarah.id, optionIDs: [destinationOptions[0].id]),
                                   ],
                                   createdAt: daysFromNow(-11))

        let stayOptions = [VoteOption(label: "Hotel", subtitle: "Easy, central"),
                           VoteOption(label: "Airbnb", subtitle: "Cheaper, one big kitchen")]
        let stayVote = Vote(eventID: dublin.id,
                            createdByID: sarah.id,
                            title: "Hotel or Airbnb?",
                            kind: .freeform,
                            options: stayOptions,
                            deadline: daysFromNow(6, hour: 20),
                            responses: [
                                VoteResponse(userID: sarah.id, optionIDs: [stayOptions[1].id]),
                                VoteResponse(userID: pete.id, optionIDs: [stayOptions[1].id]),
                            ])

        let dublinTasks = [
            EventTask(eventID: dublin.id, title: "Shortlist flights", detail: "Aer Lingus vs Ryanair, Friday evening out.",
                      assigneeID: gary.id, createdByID: user.id, dueDate: daysFromNow(-1)),
            EventTask(eventID: dublin.id, title: "Find an Airbnb near Temple Bar",
                      assigneeID: user.id, createdByID: user.id, status: .inProgress, dueDate: daysFromNow(7)),
            EventTask(eventID: dublin.id, title: "Book Guinness Storehouse tour",
                      assigneeID: sarah.id, createdByID: pete.id, status: .complete,
                      completedAt: daysFromNow(-2)),
        ]

        let depositShares = [
            PaymentShare(userID: gary.id, state: .owed),
            PaymentShare(userID: dave.id, state: .markedPaid, markedPaidAt: daysFromNow(-1)),
            PaymentShare(userID: sarah.id, state: .confirmed, markedPaidAt: daysFromNow(-3), confirmedAt: daysFromNow(-2)),
            PaymentShare(userID: user.id, state: .confirmed, markedPaidAt: daysFromNow(-4), confirmedAt: daysFromNow(-4)),
        ]
        let deposit = Payment(eventID: dublin.id,
                              title: "Accommodation deposit",
                              amountPerPerson: 50,
                              paidByID: pete.id,
                              shares: depositShares,
                              dueDate: daysFromNow(3))

        let dublinMessages: [ChatMessage] = [
            ChatMessage(eventID: dublin.id, senderID: pete.id,
                        text: "Right. Dublin. Who's in?", createdAt: daysFromNow(-12)),
            ChatMessage(eventID: dublin.id, senderID: sarah.id,
                        text: "Obviously in. Already looking at flights ✈️",
                        reactions: ["🔥": [pete.id, dave.id]], createdAt: daysFromNow(-12)),
            ChatMessage(eventID: dublin.id, senderID: nil, kind: .system,
                        text: "Pete locked in Dublin as the destination.", createdAt: daysFromNow(-11)),
            ChatMessage(eventID: dublin.id, senderID: gary.id,
                        text: "I'll sort flights this week, promise.", createdAt: daysFromNow(-5)),
            ChatMessage(eventID: dublin.id, senderID: dave.id,
                        text: "Gary making promises again. Screenshot saved 📸",
                        reactions: ["😂": [pete.id, sarah.id, user.id]], createdAt: daysFromNow(-5)),
            ChatMessage(eventID: dublin.id, senderID: nil, kind: .system,
                        text: "Sarah finished the task: Book Guinness Storehouse tour.", createdAt: daysFromNow(-2)),
            ChatMessage(eventID: dublin.id, senderID: sarah.id,
                        text: "Storehouse booked! Skip-the-line like VIPs 🍺", createdAt: daysFromNow(-2)),
        ]

        let dublinBingo = BingoGame(eventID: dublin.id,
                                    status: .collecting,
                                    submissions: [
                                        BingoSubmission(authorID: dave.id, text: "Gary misses the flight", approved: true),
                                        BingoSubmission(authorID: pete.id, text: "Someone orders a full Irish at 4pm", approved: true),
                                        BingoSubmission(authorID: sarah.id, text: "Dave claims he 'knows a shortcut'", approved: true),
                                        BingoSubmission(authorID: gary.id, text: "Pete cries at a busker", approved: true),
                                        BingoSubmission(authorID: dave.id, text: "Someone loses their room key", approved: true),
                                        BingoSubmission(authorID: sarah.id, text: "Group photo where everyone blinks", approved: false),
                                    ])

        // MARK: Newcastle Night Out — wrapped, lives in the Memory Vault.

        let newcastleCrew = [user.id, pete.id, gary.id, dave.id, mia.id]
        let newcastleDate = daysFromNow(-95, hour: 19)
        let newcastle = Event(title: "Newcastle Night Out",
                              detail: "Toon takeover for Pete's birthday.",
                              kind: .nightOut,
                              phase: .completed,
                              leaderID: pete.id,
                              participantIDs: newcastleCrew,
                              startDate: newcastleDate,
                              endDate: newcastleDate,
                              locationName: "Newcastle",
                              coverPaletteIndex: 1,
                              moodEmoji: "🌙",
                              lockedAt: daysFromNow(-110),
                              createdAt: daysFromNow(-130))

        let newcastlePhotos: [EventPhoto] = [
            EventPhoto(eventID: newcastle.id, uploaderID: mia.id, caption: "Pre-drinks faces",
                       placeholderPaletteIndex: 4, placeholderSymbol: "person.3.fill",
                       reactions: ["😂": [pete.id, dave.id, user.id]], createdAt: newcastleDate),
            EventPhoto(eventID: newcastle.id, uploaderID: dave.id, caption: "Quayside at 1am",
                       placeholderPaletteIndex: 1, placeholderSymbol: "moon.stars.fill",
                       reactions: ["🔥": [mia.id, pete.id]], createdAt: newcastleDate),
            EventPhoto(eventID: newcastle.id, uploaderID: pete.id, caption: "Birthday boy",
                       placeholderPaletteIndex: 3, placeholderSymbol: "birthday.cake.fill",
                       reactions: ["❤️": [mia.id, gary.id, dave.id, user.id]], createdAt: newcastleDate),
            EventPhoto(eventID: newcastle.id, uploaderID: user.id, caption: "The 3am kebab summit",
                       placeholderPaletteIndex: 0, placeholderSymbol: "fork.knife",
                       createdAt: newcastleDate),
        ]

        let newcastleMessages: [ChatMessage] = [
            ChatMessage(eventID: newcastle.id, senderID: pete.id,
                        text: "Best birthday yet. Heroes, all of you.",
                        reactions: ["❤️": [mia.id, dave.id, gary.id, user.id]],
                        createdAt: daysFromNow(-94)),
            ChatMessage(eventID: newcastle.id, senderID: nil, kind: .system,
                        text: "Event wrapped. The memories are in the vault.", createdAt: daysFromNow(-94)),
        ]

        let newcastleTabShares = [
            PaymentShare(userID: user.id, state: .confirmed, markedPaidAt: daysFromNow(-100), confirmedAt: daysFromNow(-99)),
            PaymentShare(userID: dave.id, state: .confirmed, markedPaidAt: daysFromNow(-98), confirmedAt: daysFromNow(-97)),
            PaymentShare(userID: gary.id, state: .confirmed, markedPaidAt: daysFromNow(-93), confirmedAt: daysFromNow(-92)),
            PaymentShare(userID: mia.id, state: .confirmed, markedPaidAt: daysFromNow(-101), confirmedAt: daysFromNow(-100)),
        ]
        let newcastleTab = Payment(eventID: newcastle.id,
                                   title: "Karaoke room + first round",
                                   amountPerPerson: 22,
                                   paidByID: pete.id,
                                   shares: newcastleTabShares,
                                   createdAt: daysFromNow(-102))

        let newcastleBingoSubmissions = [
            BingoSubmission(authorID: dave.id, text: "Gary does karaoke uninvited", approved: true),
            BingoSubmission(authorID: mia.id, text: "Pete loses his coat", approved: true),
            BingoSubmission(authorID: gary.id, text: "Taxi driver gets a life story", approved: true),
            BingoSubmission(authorID: pete.id, text: "Dave falls asleep somewhere weird", approved: true),
            BingoSubmission(authorID: user.id, text: "Someone adopts a stranger into the group", approved: true),
            BingoSubmission(authorID: mia.id, text: "Kebab before midnight", approved: true),
        ]
        let newcastleCards = BingoCardGenerator.deal(submissions: newcastleBingoSubmissions,
                                                     to: newcastleCrew, seed: 42)
        var finishedCards = newcastleCards
        if let daveIndex = finishedCards.firstIndex(where: { $0.ownerID == dave.id }) {
            finishedCards[daveIndex].squares = finishedCards[daveIndex].squares.map {
                BingoSquare(submissionID: $0.submissionID, claimedByID: dave.id, confirmed: true)
            }
        }
        let newcastleBingo = BingoGame(eventID: newcastle.id,
                                       status: .finished,
                                       submissions: newcastleBingoSubmissions,
                                       cards: finishedCards,
                                       winnerID: dave.id,
                                       createdAt: daysFromNow(-120))

        snapshot.events = [dublin, newcastle]
        snapshot.votes = [dateVote, destinationVote, stayVote]
        snapshot.tasks = dublinTasks
        snapshot.payments = [deposit, newcastleTab]
        snapshot.messages = dublinMessages + newcastleMessages
        snapshot.photos = newcastlePhotos
        snapshot.bingoGames = [dublinBingo, newcastleBingo]
        return snapshot
    }
}
