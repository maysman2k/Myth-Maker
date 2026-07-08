import Foundation

/// Triggers the AI News Scanner workflow on demand via the GitHub API, so
/// an editor doesn't have to wait for the 6-hour schedule. Requires a
/// GitHub personal access token with Actions write access to the repo,
/// stored in the Keychain — never in the app's JSON store.
enum GitHubWorkflowService {
    static let tokenKeychainKey = "github-actions-token"
    static let owner = "maysman2k"
    static let repo = "Myth-Maker"
    static let workflowFile = "news-scanner.yml"
    /// Always dispatch against main — the branch the app's draft feed reads.
    static let ref = "main"

    enum TriggerError: LocalizedError {
        case badToken
        case workflowNotFound
        case permission(String)
        case failed(Int)

        var errorDescription: String? {
            switch self {
            case .badToken:
                return "GitHub rejected the token — it can read but not run Actions. Set the token's “Actions” permission to “Read and write” (not just “Read”) and try again."
            case .workflowNotFound:
                return "GitHub couldn't find the scanner workflow on \(ref). Make sure the branch is up to date."
            case .permission(let detail):
                return detail
            case .failed(let code):
                return "GitHub returned an unexpected response (\(code)). Try again in a moment."
            }
        }
    }

    /// Verifies the token can actually do what the admin tools need —
    /// crucially, that it has *write* access, not just read. A read-only
    /// token passes simple GET checks but is then rejected when it tries to
    /// run the scanner or save sources, which is exactly the confusing case
    /// this guards against. The repo endpoint's `permissions.push` flag is
    /// true only when the token has repository write access.
    static func verifyToken(_ token: String) async throws {
        let repoURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: repoURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TriggerError.failed(0) }
        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw TriggerError.permission("GitHub rejected this token. Double-check you copied it in full and that the Resource owner is \(owner) with \(repo) selected.")
        case 404:
            throw TriggerError.permission("This token can't see \(owner)/\(repo). When creating it, set Resource owner to \(owner) and Repository access to “Only select repositories → \(repo)”.")
        default:
            throw TriggerError.failed(http.statusCode)
        }

        let push = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
            .flatMap { $0["permissions"] as? [String: Any] }
            .flatMap { $0["push"] as? Bool } ?? false
        guard push else {
            throw TriggerError.permission("This token can read \(owner)/\(repo) but not write to it — that's why runs and source edits are rejected. In the token's Repository permissions, set BOTH “Actions” and “Contents” to “Read and write” (not just “Read”), regenerate, and paste the new token.")
        }
    }

    static func runNewsScanner(token: String) async throws {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/actions/workflows/\(workflowFile)/dispatches")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["ref": ref])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TriggerError.failed(0) }
        switch http.statusCode {
        case 204:
            return
        case 401, 403:
            throw TriggerError.badToken
        case 404, 422:
            throw TriggerError.workflowNotFound
        default:
            throw TriggerError.failed(http.statusCode)
        }
    }
}
