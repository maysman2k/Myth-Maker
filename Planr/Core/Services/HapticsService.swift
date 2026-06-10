import UIKit

/// Tactile moments: vote locked, task complete, payment confirmed, bingo win.
/// Respects the system Reduce Motion-adjacent expectations by staying subtle.
@MainActor
final class HapticsService {
    func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// The big one — used when an event locks down.
    func lockdown() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
