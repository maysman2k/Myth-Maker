import Foundation

/// A shared Wait Less link, resolved into something the app can open.
enum DeepLink: Identifiable, Hashable {
    case route(serviceID: Int, line: String, description: String)
    case stop(atco: String, name: String)

    var id: String {
        switch self {
        case .route(let serviceID, _, _): return "route-\(serviceID)"
        case .stop(let atco, _): return "stop-\(atco)"
        }
    }
}

/// Parses both `waitless://share?…` (custom scheme, works once installed) and
/// `https://waitless.bricksinabag.com/share?…` (Universal Link) into a DeepLink.
enum DeepLinkParser {
    static func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let isShare = components.host == "share" || components.path.hasSuffix("share")
        guard isShare else { return nil }

        var query: [String: String] = [:]
        for item in components.queryItems ?? [] where item.value != nil {
            query[item.name] = item.value
        }

        switch query["type"] ?? "bus" {
        case "stop":
            guard let atco = query["atco"], !atco.isEmpty else { return nil }
            return .stop(atco: atco, name: query["name"] ?? "Stop")
        default: // "bus" or "route" both open the route
            guard let value = query["service"], let serviceID = Int(value) else { return nil }
            return .route(serviceID: serviceID,
                          line: query["line"] ?? "Bus",
                          description: query["to"] ?? "")
        }
    }
}
