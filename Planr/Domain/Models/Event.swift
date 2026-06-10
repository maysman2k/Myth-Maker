import Foundation

enum EventPhase: String, Codable, CaseIterable, Comparable {
    case draft
    case planning
    case lockdown
    case detailedPlanning
    case live
    case completed
    case archived

    var label: String {
        switch self {
        case .draft: return "Draft"
        case .planning: return "Planning"
        case .lockdown: return "Locked in"
        case .detailedPlanning: return "Finishing touches"
        case .live: return "Live"
        case .completed: return "Wrapped"
        case .archived: return "Archived"
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: EventPhase, rhs: EventPhase) -> Bool { lhs.order < rhs.order }
}

/// Presentation mode derived from phase + proximity, per the emotionally-aware-modes brief.
enum EventMode {
    case planning   // clear, action-led
    case lockdown   // confident, settled
    case hype       // countdown-led, event is close
    case live       // glanceable, practical
    case memory     // warm, photo-led
}

enum EventKind: String, Codable, CaseIterable, Identifiable {
    case nightOut, weekendTrip, holiday, stagDo, henDo, concert
    case sport, movieNight, workSocial, family, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nightOut: return "Night out"
        case .weekendTrip: return "Weekend trip"
        case .holiday: return "Holiday"
        case .stagDo: return "Stag do"
        case .henDo: return "Hen do"
        case .concert: return "Concert"
        case .sport: return "Sport"
        case .movieNight: return "Movie night"
        case .workSocial: return "Work social"
        case .family: return "Family"
        case .custom: return "Something else"
        }
    }

    var symbol: String {
        switch self {
        case .nightOut: return "moon.stars.fill"
        case .weekendTrip: return "suitcase.rolling.fill"
        case .holiday: return "sun.max.fill"
        case .stagDo: return "crown.fill"
        case .henDo: return "sparkles"
        case .concert: return "music.mic"
        case .sport: return "sportscourt.fill"
        case .movieNight: return "popcorn.fill"
        case .workSocial: return "cup.and.saucer.fill"
        case .family: return "house.fill"
        case .custom: return "star.fill"
        }
    }
}

enum PrivacyLevel: String, Codable, CaseIterable {
    case inviteOnly
    case approvalRequired

    var label: String {
        switch self {
        case .inviteOnly: return "Anyone with the link"
        case .approvalRequired: return "Organiser approves joins"
        }
    }
}

struct Event: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var kind: EventKind
    var phase: EventPhase
    var leaderID: String
    var coLeaderIDs: [String]
    var participantIDs: [String]
    var startDate: Date?
    var endDate: Date?
    var locationName: String?
    var privacy: PrivacyLevel
    var inviteCode: String
    var coverPaletteIndex: Int
    var moodEmoji: String
    var budgetNote: String?
    var shameBoardEnabled: Bool
    var lockedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString,
         title: String,
         detail: String = "",
         kind: EventKind = .custom,
         phase: EventPhase = .planning,
         leaderID: String,
         coLeaderIDs: [String] = [],
         participantIDs: [String],
         startDate: Date? = nil,
         endDate: Date? = nil,
         locationName: String? = nil,
         privacy: PrivacyLevel = .inviteOnly,
         inviteCode: String = InviteCodeFactory.generate(),
         coverPaletteIndex: Int = 0,
         moodEmoji: String = "🎉",
         budgetNote: String? = nil,
         shameBoardEnabled: Bool = false,
         lockedAt: Date? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.phase = phase
        self.leaderID = leaderID
        self.coLeaderIDs = coLeaderIDs
        self.participantIDs = participantIDs
        self.startDate = startDate
        self.endDate = endDate
        self.locationName = locationName
        self.privacy = privacy
        self.inviteCode = inviteCode
        self.coverPaletteIndex = coverPaletteIndex
        self.moodEmoji = moodEmoji
        self.budgetNote = budgetNote
        self.shameBoardEnabled = shameBoardEnabled
        self.lockedAt = lockedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Core details (date, location, main plan) are locked from Lockdown onwards.
    var isLockedDown: Bool {
        phase >= .lockdown && phase < .completed
    }

    var isFinished: Bool {
        phase >= .completed
    }

    func mode(now: Date = .now) -> EventMode {
        switch phase {
        case .draft, .planning:
            return .planning
        case .lockdown, .detailedPlanning:
            if let startDate, DateUtilities.daysUntil(startDate, from: now) <= 14 {
                return .hype
            }
            return .lockdown
        case .live:
            return .live
        case .completed, .archived:
            return .memory
        }
    }

    func role(of userID: String) -> EventRole {
        if userID == leaderID { return .leader }
        if coLeaderIDs.contains(userID) { return .coLeader }
        return .participant
    }
}

enum EventRole {
    case leader, coLeader, participant

    var canManage: Bool { self != .participant }
}
