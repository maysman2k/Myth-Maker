import Foundation

/// Fetches AI-drafted articles produced by the scheduled news scanner
/// (NewsScanner/scanner.py → drafts.json in this repo). The queue only ever
/// feeds the admin review screen — nothing publishes without approval.
enum DraftFeedService {
    enum FeedError: LocalizedError {
        case badResponse

        var errorDescription: String? {
            "The draft feed isn't reachable right now."
        }
    }

    /// Tried in order: the default branch first, then the development
    /// branch so the feed works before the app branch is merged.
    static let feedURLs: [URL] = [
        URL(string: "https://raw.githubusercontent.com/maysman2k/Myth-Maker/main/NewsScanner/drafts.json")!,
        URL(string: "https://raw.githubusercontent.com/maysman2k/Myth-Maker/claude/ios-app-from-md-ofm4l4/NewsScanner/drafts.json")!
    ]

    static func fetchLatest() async throws -> [AIDraft] {
        var lastError: Error = FeedError.badResponse
        for url in feedURLs {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw FeedError.badResponse
                }
                return try decode(data)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    static func decode(_ data: Data) throws -> [AIDraft] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([AIDraft].self, from: data)
    }
}
