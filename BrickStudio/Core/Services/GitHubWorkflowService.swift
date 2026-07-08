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
                return "GitHub rejected the token. Check it has Actions write access to \(owner)/\(repo)."
            case .workflowNotFound:
                return "GitHub couldn't find the scanner workflow on \(ref). Make sure the branch is up to date."
            case .permission(let detail):
                return detail
            case .failed(let code):
                return "GitHub returned an unexpected response (\(code)). Try again in a moment."
            }
        }
    }

    /// Checks the saved token can do everything the admin tools need:
    /// read Actions (to trigger scans) and read repo contents (to manage
    /// the source list). Throws a specific, human-readable error when a
    /// permission is missing so the admin knows exactly what to fix.
    static func verifyToken(_ token: String) async throws {
        let actionsURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/actions/workflows/\(workflowFile)")!
        try await check(
            url: actionsURL,
            token: token,
            failureDetail: "Token can't access Actions on \(owner)/\(repo). In the token's permissions set Actions to Read and write, and make sure the resource owner is \(owner) with this repository selected."
        )
        let contentsURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/NewsScanner/sources.json?ref=\(ref)")!
        try await check(
            url: contentsURL,
            token: token,
            failureDetail: "Token can't read the repo's files, so source editing won't work. In the token's permissions set Contents to Read and write."
        )
    }

    private static func check(url: URL, token: String, failureDetail: String) async throws {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TriggerError.failed(0) }
        guard http.statusCode == 200 else {
            throw TriggerError.permission(failureDetail)
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
