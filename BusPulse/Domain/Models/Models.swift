import CoreLocation
import Foundation

// MARK: - Stop

struct Stop: Identifiable, Codable, Hashable {
    /// ATCO code — the national stop identifier.
    var id: String
    var name: String
    /// "Stand B", "opp", "adj" — the little label on the flag.
    var indicator: String?
    /// Compass bearing the bus faces when departing, in degrees.
    var bearing: Double?
    var latitude: Double
    var longitude: Double
    /// Line names calling here, e.g. ["43", "X41"].
    var lineNames: [String]
    /// SMS code printed on the stop flag (NaPTAN code).
    var naptanCode: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        if let indicator, !indicator.isEmpty { return "\(name) (\(indicator))" }
        return name
    }
}

// MARK: - Service (a bus route)

struct Service: Identifiable, Codable, Hashable {
    var id: Int
    var lineName: String
    /// "Manchester - Stockport via A6"
    var description: String
    var mode: String?
    var slug: String?

    var webURL: URL? {
        slug.flatMap { URL(string: "https://bustimes.org/services/\($0)") }
    }
}

// MARK: - Live vehicle position

struct VehiclePosition: Identifiable, Hashable {
    /// Journey/location identifier from the live feed.
    var id: Int
    var journeyID: Int?
    var serviceID: Int?
    var tripID: Int?
    var latitude: Double
    var longitude: Double
    /// Heading in degrees, if the feed reports one.
    var heading: Double?
    var recordedAt: Date?
    var lineName: String?
    var destination: String?
    /// "1234 - YX19 ABC" style fleet description.
    var vehicleName: String?
    var vehicleURL: String?
    /// Hex colour extracted from the operator livery CSS, if available.
    var liveryBackground: String?
    var liveryForeground: String?
    /// Reported delay in seconds (positive = late).
    var delaySeconds: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var routeLabel: String { lineName ?? "Bus" }

    var webURL: URL? {
        vehicleURL.flatMap { URL(string: "https://bustimes.org\($0)") }
    }
}

// MARK: - Timetable (cached for offline use)

struct CachedTimetable: Codable, Identifiable {
    var service: Service
    /// The operating date the trips were fetched for.
    var date: Date
    var downloadedAt: Date
    var trips: [TimetableTrip]

    var id: Int { service.id }
}

struct TimetableTrip: Codable, Identifiable, Hashable {
    var id: Int
    var headsign: String?
    var times: [TimetableStopTime]

    /// Departure time of the first stop, used for sorting and display.
    var startSeconds: Int? { times.first?.departureSeconds }
}

struct TimetableStopTime: Codable, Hashable {
    var atcoCode: String?
    var stopName: String?
    /// Seconds after midnight; values >= 86,400 mean "after midnight tonight"
    /// (timetables use 24:xx/25:xx for trips that run past midnight).
    var departureSeconds: Int?
    var arrivalSeconds: Int?
    /// Stop coordinates, where the server provides them — used to work out how
    /// far along its journey a live bus is.
    var latitude: Double?
    var longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Journey planner (direct buses)

struct JourneyOption: Identifiable {
    var service: Service
    var fromStopName: String
    var toStopName: String
    /// Next few departure times at the boarding stop, e.g. ["07:05", "07:35"].
    var departures: [String]
    /// Walk to the boarding stop / from the alighting stop, in metres.
    var fromWalkMeters: Int?
    var toWalkMeters: Int?

    var id: Int { service.id }
}

/// A full plan for a from→to query: direct buses plus single-change journeys.
struct JourneyPlan {
    var direct: [JourneyOption]
    var itineraries: [JourneyItinerary]
}

/// A journey made of legs — bus, (walk), bus — when no single bus does it.
struct JourneyItinerary: Identifiable {
    let id = UUID()
    var changes: Int
    /// Final arrival time at the destination, "HH:MM:SS".
    var arrival: String?
    var legs: [JourneyLeg]
}

struct JourneyLeg: Identifiable {
    let id = UUID()
    enum Kind: String { case bus, walk }
    var kind: Kind
    // Bus legs:
    var service: Service? = nil
    var fromStopName: String? = nil
    var toStopName: String? = nil
    var departure: String? = nil
    var arrival: String? = nil
    /// Calling points along this leg, board → alight.
    var stops: [JourneyLegStop] = []
    // Walk legs:
    var walkMeters: Int? = nil
}

struct JourneyLegStop: Identifiable {
    let id = UUID()
    var name: String
    /// "HH:MM:SS" (or "HH:MM").
    var time: String?
}

// MARK: - A computed departure for a departure board

struct Departure: Identifiable, Hashable {
    var tripID: Int
    var lineName: String
    var destination: String?
    /// Absolute departure date resolved against a reference day.
    var departure: Date

    var id: String { "\(tripID)-\(departure.timeIntervalSince1970)" }
}
