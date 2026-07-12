import Foundation
import UIKit

struct SupabaseSession: Codable {
    var accessToken: String
    var refreshToken: String?
    var userID: UUID
}

enum SupabaseService {
    static let sessionKeychainKey = "supabase-session"

    static var isConfigured: Bool {
        baseURL != nil && !anonKey.isEmpty
    }

    private static var baseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !raw.isEmpty,
              !raw.contains("$(") else { return nil }
        return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private static var anonKey: String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !raw.contains("$(") else { return "" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum ServiceError: LocalizedError {
        case notConfigured
        case invalidResponse(String)
        case emailConfirmationRequired
        case failed(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase is not configured in this build."
            case .invalidResponse(let message):
                return message
            case .emailConfirmationRequired:
                return "Supabase created the account, but email confirmation is still on. Disable Confirm email in Authentication > Sign In / Providers > Email, then delete this test user and sign up again."
            case .failed(let code, let message):
                return "Supabase request failed (\(code)): \(message)"
            }
        }
    }

    static func saveSession(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session),
              let string = String(data: data, encoding: .utf8) else { return }
        KeychainStore.save(string, for: sessionKeychainKey)
    }

    static func loadSession() -> SupabaseSession? {
        guard let string = KeychainStore.load(sessionKeychainKey),
              let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    static func clearSession() {
        KeychainStore.delete(sessionKeychainKey)
    }

    static func signUp(email: String, password: String, displayName: String) async throws -> (SupabaseSession, UserAccount) {
        let response: AuthResponse = try await request(
            path: "/auth/v1/signup",
            method: "POST",
            body: SignUpBody(email: email, password: password, data: ["display_name": displayName]),
            token: nil,
            preferRepresentation: false
        )
        let session: SupabaseSession
        if let returnedSession = response.sessionValue {
            session = returnedSession
        } else {
            session = try await authenticate(email: email, password: password)
        }
        try await upsertProfile(userID: session.userID, displayName: displayName, email: email, role: .user, token: session.accessToken)
        let account = try await fetchProfile(userID: session.userID, token: session.accessToken)
        saveSession(session)
        return (session, account)
    }

    static func signIn(email: String, password: String) async throws -> (SupabaseSession, UserAccount) {
        let session = try await authenticate(email: email, password: password)
        let account = try await fetchProfile(userID: session.userID, token: session.accessToken)
        saveSession(session)
        return (session, account)
    }

    private static func authenticate(email: String, password: String) async throws -> SupabaseSession {
        let response: AuthResponse = try await request(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            body: SignInBody(email: email, password: password),
            token: nil,
            preferRepresentation: false
        )
        guard let session = response.sessionValue else {
            throw ServiceError.invalidResponse("Supabase signed in, but did not return a usable session. Check that Email/password sign-in is enabled in Authentication > Sign In / Providers > Email.")
        }
        return session
    }

    static func fetchPublishedArticles() async throws -> [Article] {
        let rows: [ArticleRow] = try await request(
            path: "/rest/v1/articles?status=eq.published&order=published_at.desc",
            method: "GET",
            token: loadSession()?.accessToken
        )
        return rows.map(\.article)
    }

    static func fetchSubmittedStories(adminOnly: Bool, userID: UUID?) async throws -> [SubmittedStory] {
        var path = "/rest/v1/story_submissions?order=submitted_at.asc"
        if adminOnly {
            path += "&status=eq.pendingReview"
        } else if let userID {
            path += "&user_id=eq.\(userID.uuidString.lowercased())"
        }
        let rows: [SubmittedStoryRow] = try await request(path: path, method: "GET", token: loadSession()?.accessToken)
        return rows.map(\.submission)
    }

    static func upsertSubmittedStory(_ submission: SubmittedStory) async throws {
        let _: [SubmittedStoryRow] = try await request(
            path: "/rest/v1/story_submissions?on_conflict=id",
            method: "POST",
            body: SubmittedStoryRow(submission: submission),
            token: loadSession()?.accessToken,
            preferRepresentation: true,
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
    }

    static func upsertArticle(_ article: Article) async throws {
        let _: [ArticleRow] = try await request(
            path: "/rest/v1/articles?on_conflict=id",
            method: "POST",
            body: ArticleRow(article: article),
            token: loadSession()?.accessToken,
            preferRepresentation: true,
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
    }

    static func updateSubmittedStoryStatus(_ submission: SubmittedStory) async throws {
        let _: [SubmittedStoryRow] = try await request(
            path: "/rest/v1/story_submissions?id=eq.\(submission.id.uuidString.lowercased())",
            method: "PATCH",
            body: SubmittedStoryRow(submission: submission),
            token: loadSession()?.accessToken,
            preferRepresentation: true
        )
    }

    static func uploadStoryMediaReferences(_ references: [String]) async throws -> [String] {
        guard let session = loadSession() else { return references }
        var uploaded: [String] = []
        for reference in references {
            if reference.hasPrefix("local-image://"),
               let filename = localFilename(from: reference, prefix: "local-image://"),
               let image = ImageStore.load(filename),
               let data = image.jpegData(compressionQuality: 0.86) {
                uploaded.append(try await uploadStoryMedia(data: data, extension: "jpg", contentType: "image/jpeg", session: session))
            } else if reference.hasPrefix("local-video://"),
                      let filename = localFilename(from: reference, prefix: "local-video://"),
                      let url = ImageStore.videoURL(filename),
                      let data = try? Data(contentsOf: url) {
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                uploaded.append(try await uploadStoryMedia(data: data, extension: ext, contentType: contentType(for: ext), session: session))
            } else {
                uploaded.append(reference)
            }
        }
        return uploaded
    }

    private static func upsertProfile(userID: UUID, displayName: String, email: String, role: UserRole, token: String) async throws {
        let body = ProfileRow(id: userID, displayName: displayName, email: email, role: role.rawValue, createdAt: Date(), updatedAt: Date())
        let _: [ProfileRow] = try await request(
            path: "/rest/v1/profiles?on_conflict=id",
            method: "POST",
            body: body,
            token: token,
            preferRepresentation: true,
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
    }

    private static func uploadStoryMedia(data: Data, extension ext: String, contentType: String, session: SupabaseSession) async throws -> String {
        guard let baseURL else { throw ServiceError.notConfigured }
        let path = "\(session.userID.uuidString.lowercased())/\(UUID().uuidString).\(ext)"
        let url = URL(string: baseURL.absoluteString + "/storage/v1/object/story-media/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("3600", forHTTPHeaderField: "cache-control")
        request.httpBody = data
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse("Supabase returned a response the app could not read.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(SupabaseError.self, from: responseData).message) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ServiceError.failed(http.statusCode, message)
        }
        return baseURL.absoluteString + "/storage/v1/object/public/story-media/\(path)"
    }

    private static func localFilename(from reference: String, prefix: String) -> String? {
        guard reference.hasPrefix(prefix) else { return nil }
        return String(reference.dropFirst(prefix.count))
    }

    private static func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "mp4": return "video/mp4"
        case "m4v": return "video/x-m4v"
        default: return "video/quicktime"
        }
    }

    private static func fetchProfile(userID: UUID, token: String) async throws -> UserAccount {
        let rows: [ProfileRow] = try await request(
            path: "/rest/v1/profiles?id=eq.\(userID.uuidString.lowercased())&limit=1",
            method: "GET",
            token: token
        )
        guard let row = rows.first else {
            throw ServiceError.invalidResponse("Your Supabase account exists, but the app profile row is missing. Run the BrickStudio schema again, then sign up with a fresh test user.")
        }
        return row.account
    }

    private static func request<T: Decodable>(
        path: String,
        method: String,
        token: String?,
        preferRepresentation: Bool = false
    ) async throws -> T {
        try await request(path: path, method: method, bodyData: nil, token: token, preferRepresentation: preferRepresentation, extraHeaders: [:])
    }

    private static func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        token: String?,
        preferRepresentation: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        let encoder = JSONEncoder.supabase
        return try await request(
            path: path,
            method: method,
            bodyData: try encoder.encode(body),
            token: token,
            preferRepresentation: preferRepresentation,
            extraHeaders: extraHeaders
        )
    }

    private static func request<T: Decodable>(
        path: String,
        method: String,
        bodyData: Data?,
        token: String?,
        preferRepresentation: Bool,
        extraHeaders: [String: String]
    ) async throws -> T {
        guard let baseURL else { throw ServiceError.notConfigured }
        var request = URLRequest(url: baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path))
        if path.contains("?"), let url = URL(string: baseURL.absoluteString + path) {
            request = URLRequest(url: url)
        }
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token ?? anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse("Supabase returned a response the app could not read.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(SupabaseError.self, from: data).message) ?? String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ServiceError.failed(http.statusCode, message)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        do {
            return try JSONDecoder.supabase.decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "No response body."
            throw ServiceError.invalidResponse("Supabase returned data in an unexpected shape: \(error.localizedDescription). Response: \(body)")
        }
    }
}

private struct EmptyResponse: Decodable {}

private struct SupabaseError: Decodable {
    var message: String
}

private struct SignUpBody: Encodable {
    var email: String
    var password: String
    var data: [String: String]
}

private struct SignInBody: Encodable {
    var email: String
    var password: String
}

private struct AuthResponse: Decodable {
    struct User: Decodable {
        var id: UUID
        var email: String?

        enum CodingKeys: String, CodingKey {
            case id, email
        }
    }

    struct Session: Decodable {
        var accessToken: String?
        var refreshToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    var accessToken: String?
    var refreshToken: String?
    var session: Session?
    var user: User?

    var sessionValue: SupabaseSession? {
        guard let accessToken = accessToken ?? session?.accessToken,
              let userID = user?.id else { return nil }
        let refreshToken = refreshToken ?? session?.refreshToken
        return SupabaseSession(accessToken: accessToken, refreshToken: refreshToken, userID: userID)
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case session, user
    }
}

private struct ProfileRow: Codable {
    var id: UUID
    var displayName: String
    var email: String
    var role: String
    var createdAt: Date
    var updatedAt: Date

    var account: UserAccount {
        UserAccount(
            id: id,
            displayName: displayName,
            email: email,
            passwordHash: "supabase",
            role: UserRole(rawValue: role) ?? .user,
            bio: "",
            favouriteTopics: [],
            favouriteClub: "",
            publicProfileEnabled: true,
            notificationPreferences: NotificationPreferences(),
            completedLessonIDs: [],
            createdAt: createdAt,
            lastActiveAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct ArticleRow: Codable {
    var id: UUID
    var title: String
    var slug: String
    var summary: String
    var bodyMarkdown: String
    var category: String
    var tags: [String]
    var authorName: String
    var sources: [ArticleSource]
    var isRumour: Bool
    var aiAssisted: Bool
    var commentsEnabled: Bool
    var status: String
    var likeCount: Int
    var viewCount: Int
    var readTimeMinutes: Int
    var publishedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var heroImageURL: String?
    var galleryImageURLs: [String]?
    var mediaURLs: [String]?

    init(article: Article) {
        id = article.id
        title = article.title
        slug = article.slug
        summary = article.summary
        bodyMarkdown = article.bodyMarkdown
        category = article.category.rawValue
        tags = article.tags
        authorName = article.authorName
        sources = article.sources
        isRumour = article.isRumour
        aiAssisted = article.aiAssisted
        commentsEnabled = article.commentsEnabled
        status = article.status.rawValue
        likeCount = article.likeCount
        viewCount = article.viewCount
        readTimeMinutes = article.readTimeMinutes
        publishedAt = article.publishedAt
        createdAt = article.createdAt
        updatedAt = article.updatedAt
        heroImageURL = article.heroImageURL
        galleryImageURLs = article.galleryImageURLs
        mediaURLs = article.mediaURLs
    }

    var article: Article {
        Article(
            id: id,
            title: title,
            slug: slug,
            summary: summary,
            bodyMarkdown: bodyMarkdown,
            category: ArticleCategory(rawValue: category) ?? .bricksInABagUpdates,
            tags: tags,
            authorName: authorName,
            sources: sources,
            isRumour: isRumour,
            aiAssisted: aiAssisted,
            commentsEnabled: commentsEnabled,
            status: PublishStatus(rawValue: status) ?? .draft,
            likeCount: likeCount,
            viewCount: viewCount,
            readTimeMinutes: readTimeMinutes,
            publishedAt: publishedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            heroImageURL: heroImageURL,
            galleryImageURLs: galleryImageURLs,
            mediaURLs: mediaURLs
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, title, slug, summary, category, tags, sources, status
        case bodyMarkdown = "body_markdown"
        case authorName = "author_name"
        case isRumour = "is_rumour"
        case aiAssisted = "ai_assisted"
        case commentsEnabled = "comments_enabled"
        case likeCount = "like_count"
        case viewCount = "view_count"
        case readTimeMinutes = "read_time_minutes"
        case publishedAt = "published_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case heroImageURL = "hero_image_url"
        case galleryImageURLs = "gallery_image_urls"
        case mediaURLs = "media_urls"
    }
}

private struct SubmittedStoryRow: Codable {
    var id: UUID
    var userID: UUID
    var title: String
    var summary: String
    var bodyMarkdown: String
    var category: String
    var tags: [String]
    var imageReferences: [String]
    var mediaReferences: [String]
    var links: [ArticleSource]
    var isRumour: Bool
    var aiAssisted: Bool
    var status: String
    var declineCount: Int
    var latestFeedback: String?
    var publishedArticleID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var submittedAt: Date

    init(submission: SubmittedStory) {
        id = submission.id
        userID = submission.userID
        title = submission.title
        summary = submission.summary
        bodyMarkdown = submission.bodyMarkdown
        category = submission.category.rawValue
        tags = submission.tags
        imageReferences = submission.imageReferences
        mediaReferences = submission.mediaReferences
        links = submission.links
        isRumour = submission.isRumour
        aiAssisted = submission.aiAssisted
        status = submission.status.rawValue
        declineCount = submission.declineCount
        latestFeedback = submission.latestFeedback
        publishedArticleID = submission.publishedArticleID
        createdAt = submission.createdAt
        updatedAt = submission.updatedAt
        submittedAt = submission.submittedAt
    }

    var submission: SubmittedStory {
        SubmittedStory(
            id: id,
            userID: userID,
            title: title,
            summary: summary,
            bodyMarkdown: bodyMarkdown,
            category: ArticleCategory(rawValue: category) ?? .bricksInABagUpdates,
            tags: tags,
            imageReferences: imageReferences,
            mediaReferences: mediaReferences,
            links: links,
            isRumour: isRumour,
            aiAssisted: aiAssisted,
            status: SubmittedStoryStatus(rawValue: status) ?? .pendingReview,
            declineCount: declineCount,
            latestFeedback: latestFeedback,
            publishedArticleID: publishedArticleID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            submittedAt: submittedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary, category, tags, links, status
        case userID = "user_id"
        case bodyMarkdown = "body_markdown"
        case imageReferences = "image_references"
        case mediaReferences = "media_references"
        case isRumour = "is_rumour"
        case aiAssisted = "ai_assisted"
        case declineCount = "decline_count"
        case latestFeedback = "latest_feedback"
        case publishedArticleID = "published_article_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case submittedAt = "submitted_at"
    }
}

private extension JSONEncoder {
    static var supabase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.supabase.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter.supabaseNoFractions.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Supabase date")
        }
        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let supabaseNoFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
