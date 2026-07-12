import Foundation

struct InstagramPost: Identifiable, Decodable, Hashable {
    var id: String
    var caption: String?
    var mediaType: String
    var mediaURL: URL?
    var thumbnailURL: URL?
    var permalink: URL?
    var timestamp: Date?

    var displayImageURL: URL? {
        thumbnailURL ?? mediaURL
    }

    enum CodingKeys: String, CodingKey {
        case id, caption, permalink, timestamp
        case mediaType = "media_type"
        case mediaURL = "media_url"
        case thumbnailURL = "thumbnail_url"
    }
}

enum InstagramFeedService {
    enum FeedError: LocalizedError {
        case notConfigured
        case badResponse
        case failed(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Instagram feed is not configured yet."
            case .badResponse:
                return "Instagram feed returned data the app could not read."
            case .failed(let code, let message):
                return "Instagram feed failed (\(code)): \(message)"
            }
        }
    }

    static var isConfigured: Bool {
        feedURL != nil
    }

    static func fetchLatest(limit: Int = 5) async throws -> [InstagramPost] {
        guard let url = feedURL(limit: limit) else { throw FeedError.notConfigured }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let anonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(FeedErrorPayload.self, from: data).error) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw FeedError.failed(http.statusCode, message)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.instagram.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter.instagramNoFractions.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Instagram date")
        }

        if let wrapped = try? decoder.decode(InstagramFeedPayload.self, from: data) {
            return Array(wrapped.posts.prefix(limit))
        }
        return Array(try decoder.decode([InstagramPost].self, from: data).prefix(limit))
    }

    private static var feedURL: URL? {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "INSTAGRAM_FEED_URL") as? String,
           !raw.isEmpty,
           !raw.contains("$("),
           let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        guard let supabaseURL else { return nil }
        return supabaseURL.appendingPathComponent("functions/v1/instagram-feed")
    }

    private static func feedURL(limit: Int) -> URL? {
        guard let feedURL else { return nil }
        var components = URLComponents(url: feedURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        return components?.url ?? feedURL
    }

    private static var supabaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private static var anonKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct InstagramFeedPayload: Decodable {
    var posts: [InstagramPost]
}

private struct FeedErrorPayload: Decodable {
    var error: String
}

private extension ISO8601DateFormatter {
    static let instagram: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let instagramNoFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
