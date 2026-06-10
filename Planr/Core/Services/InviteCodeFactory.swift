import Foundation

/// Secure random invite codes plus the share copy that goes with them.
enum InviteCodeFactory {

    /// Unambiguous alphabet — no 0/O or 1/I lookalikes.
    private static let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")

    static func generate() -> String {
        func chunk() -> String {
            String((0..<4).map { _ in alphabet.randomElement()! })
        }
        return "PLNR-\(chunk())-\(chunk())"
    }

    static func isPlausible(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let parts = trimmed.split(separator: "-")
        guard parts.count == 3, parts[0] == "PLNR" else { return false }
        let allowed = Set(alphabet)
        return parts.dropFirst().allSatisfy { part in
            part.count == 4 && part.allSatisfy(allowed.contains)
        }
    }

    /// Placeholder universal link until the planr.app domain + backend exist.
    static func shareURL(for code: String) -> URL {
        URL(string: "https://planr.app/join/\(code)")!
    }

    static func shareMessage(for event: Event) -> String {
        """
        You're invited: \(event.title) \(event.moodEmoji)
        Join on Planr with code \(event.inviteCode)
        \(shareURL(for: event.inviteCode).absoluteString)
        """
    }
}
