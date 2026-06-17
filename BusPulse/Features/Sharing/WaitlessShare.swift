import Foundation

/// Builds share links that point at the Wait Less backend, which serves a
/// small web page for each (so a recipient sees the bus/route even without
/// the app). When the app gains Universal Links (after the Apple Developer
/// account is set up), these same https links will open the app directly.
enum WaitlessShare {
    static let shareBase = "https://waitless.bricksinabag.com/share"

    static func bus(line: String, serviceID: Int?, destination: String?) -> URL {
        var components = URLComponents(string: shareBase)!
        var items = [URLQueryItem(name: "type", value: "bus"),
                     URLQueryItem(name: "line", value: line)]
        if let serviceID { items.append(URLQueryItem(name: "service", value: String(serviceID))) }
        if let destination { items.append(URLQueryItem(name: "to", value: destination)) }
        components.queryItems = items
        return components.url ?? URL(string: shareBase)!
    }

    static func route(line: String, serviceID: Int) -> URL {
        var components = URLComponents(string: shareBase)!
        components.queryItems = [URLQueryItem(name: "type", value: "route"),
                                 URLQueryItem(name: "line", value: line),
                                 URLQueryItem(name: "service", value: String(serviceID))]
        return components.url ?? URL(string: shareBase)!
    }

    static func stop(name: String, atco: String) -> URL {
        var components = URLComponents(string: shareBase)!
        components.queryItems = [URLQueryItem(name: "type", value: "stop"),
                                 URLQueryItem(name: "name", value: name),
                                 URLQueryItem(name: "atco", value: atco)]
        return components.url ?? URL(string: shareBase)!
    }

    static func busMessage(line: String, destination: String?) -> String {
        if let destination, !destination.isEmpty {
            return "🚌 I'm on the \(line) to \(destination) — follow it live on Wait Less:"
        }
        return "🚌 Follow the \(line) live on Wait Less:"
    }

    static func routeMessage(line: String, description: String) -> String {
        let detail = description.isEmpty ? "" : " (\(description))"
        return "🚌 Track the \(line)\(detail) live on Wait Less:"
    }

    static func stopMessage(name: String) -> String {
        "🚏 Bus times for \(name) on Wait Less:"
    }
}
