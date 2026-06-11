import Foundation

/// Human-readable punctuality from a delay in seconds (positive = late).
enum DelayStatus: Equatable {
    case onTime
    case late(minutes: Int)
    case early(minutes: Int)

    /// Within a minute either side counts as on time.
    init(delaySeconds: Int) {
        switch delaySeconds {
        case ..<(-59): self = .early(minutes: max(1, -delaySeconds / 60))
        case 60...: self = .late(minutes: max(1, delaySeconds / 60))
        default: self = .onTime
        }
    }

    var label: String {
        switch self {
        case .onTime: return "On time"
        case .late(let minutes): return "\(minutes) min late"
        case .early(let minutes): return "\(minutes) min early"
        }
    }
}
