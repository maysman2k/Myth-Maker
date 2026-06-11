import Foundation

/// Abstraction over the data source so the backend can be swapped
/// (e.g. straight to the DfT Bus Open Data Service) without touching features.
protocol BusTimesAPIProviding: Sendable {
    func liveVehicles(in box: BoundingBox) async throws -> [VehiclePosition]
    func liveVehicles(serviceIDs: [Int]) async throws -> [VehiclePosition]
    func nearbyStops(in box: BoundingBox) async throws -> [Stop]
    func stop(naptanCode: String) async throws -> Stop?
    func services(matching query: String) async throws -> [Service]
    func services(callingAt atcoCode: String) async throws -> [Service]
    func stops(onService serviceID: Int) async throws -> [Stop]
    func trips(serviceID: Int, date: Date) async throws -> [TimetableTrip]
    func trip(id: Int) async throws -> TimetableTrip
    func routeGeometry(serviceID: Int) async throws -> [[[Double]]]
}

enum APIError: LocalizedError {
    case badResponse(Int)
    case offline

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "The bus data service had a wobble (HTTP \(code)). Try again shortly."
        case .offline:
            return "You're offline. Saved timetables still work."
        }
    }
}

/// Client for the bus data JSON endpoints. Defaults to bustimes.org for
/// development; point `baseURL` at your own BODS-backed proxy (see
/// `Backend/`) for production — it serves identical paths and shapes.
/// Identifies itself with a proper User-Agent and keeps request volume
/// polite either way.
final class BusTimesAPI: BusTimesAPIProviding {

    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    /// Hard cap on pagination-following so a misbehaving response can
    /// never turn into an unbounded crawl.
    private let maxPages = 30

    init(baseURL: URL = URL(string: "https://bustimes.org")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "BusPulse/1.0 (iOS; contact: support@bricksinabag.com)",
            "Accept": "application/json",
        ]
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: config)
    }

    // MARK: Live vehicles

    func liveVehicles(in box: BoundingBox) async throws -> [VehiclePosition] {
        let items: [VehicleJSONItem] = try await get(path: "/vehicles.json",
                                                     queryItems: box.queryItems)
        return items.compactMap { $0.toDomain() }
    }

    func liveVehicles(serviceIDs: [Int]) async throws -> [VehiclePosition] {
        guard !serviceIDs.isEmpty else { return [] }
        let value = serviceIDs.map(String.init).joined(separator: ",")
        let items: [VehicleJSONItem] = try await get(path: "/vehicles.json",
                                                     queryItems: [URLQueryItem(name: "service", value: value)])
        return items.compactMap { $0.toDomain() }
    }

    // MARK: Stops

    func nearbyStops(in box: BoundingBox) async throws -> [Stop] {
        // The endpoint rejects boxes over 0.15 sq degrees; clamp to be safe.
        let clamped = box.clamped()
        let geo: StopsGeoJSON = try await get(path: "/stops.json", queryItems: clamped.queryItems)
        return geo.features.compactMap { $0.toDomain() }
    }

    func stop(naptanCode: String) async throws -> Stop? {
        let page: APIPage<StopDTO> = try await get(
            path: "/api/stops/",
            queryItems: [URLQueryItem(name: "naptan_code__iexact", value: naptanCode)])
        return page.results.compactMap { $0.toDomain() }.first
    }

    func stops(onService serviceID: Int) async throws -> [Stop] {
        let page: APIPage<StopDTO> = try await get(
            path: "/api/stops/",
            queryItems: [URLQueryItem(name: "service", value: String(serviceID))])
        return page.results.compactMap { $0.toDomain() }
    }

    // MARK: Services

    func services(matching query: String) async throws -> [Service] {
        let page: APIPage<ServiceDTO> = try await get(
            path: "/api/services/",
            queryItems: [URLQueryItem(name: "search", value: query)])
        return page.results.map { $0.toDomain() }
    }

    func services(callingAt atcoCode: String) async throws -> [Service] {
        let page: APIPage<ServiceDTO> = try await get(
            path: "/api/services/",
            queryItems: [URLQueryItem(name: "stops", value: atcoCode)])
        return page.results.map { $0.toDomain() }
    }

    // MARK: Timetables

    func trips(serviceID: Int, date: Date) async throws -> [TimetableTrip] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_GB")

        var trips: [TimetableTrip] = []
        var nextURL: URL? = url(path: "/api/trips/",
                                queryItems: [URLQueryItem(name: "service", value: String(serviceID)),
                                             URLQueryItem(name: "date", value: formatter.string(from: date)),
                                             URLQueryItem(name: "limit", value: "100")])
        var pages = 0
        while let url = nextURL, pages < maxPages {
            let page: APIPage<TripDTO> = try await get(url: url)
            trips.append(contentsOf: page.results.map { $0.toDomain() })
            nextURL = page.next.flatMap(URL.init(string:))
            pages += 1
        }

        // If the list serializer omitted stop times, fetch details politely
        // (sequential, capped) rather than hammering the server.
        if trips.contains(where: { $0.times.isEmpty }) {
            for (index, trip) in trips.enumerated().prefix(200) where trip.times.isEmpty {
                if let detailed = try? await self.trip(id: trip.id) {
                    trips[index] = detailed
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        return trips.sorted { ($0.startSeconds ?? 0) < ($1.startSeconds ?? 0) }
    }

    func trip(id: Int) async throws -> TimetableTrip {
        let dto: TripDTO = try await get(path: "/api/trips/\(id)/", queryItems: [])
        return dto.toDomain()
    }

    func routeGeometry(serviceID: Int) async throws -> [[[Double]]] {
        let dto: ServiceGeometryDTO = try await get(path: "/services/\(serviceID).json",
                                                    queryItems: [])
        return dto.geometry?.lineStrings ?? []
    }

    // MARK: Plumbing

    private func url(path: String, queryItems: [URLQueryItem]) -> URL {
        // Build from a string so trailing slashes survive — the API
        // redirects slash-less paths, which would double every request.
        var components = URLComponents(string: baseURL.absoluteString + path)!
        components.queryItems = queryItems.isEmpty
            ? [URLQueryItem(name: "format", value: "json")]
            : queryItems + [URLQueryItem(name: "format", value: "json")]
        return components.url!
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        try await get(url: url(path: path, queryItems: queryItems))
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.badResponse(http.statusCode)
            }
            return try decoder.decode(T.self, from: data)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw APIError.offline
        }
    }
}
