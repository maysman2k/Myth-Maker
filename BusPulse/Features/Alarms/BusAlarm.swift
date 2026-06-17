import CoreLocation
import Foundation

/// One selectable alarm distance, stored internally as metres so the
/// underlying maths is unit-agnostic.
struct AlarmDistanceOption: Identifiable, Hashable {
    let metres: Double
    let label: String
    var id: Double { metres }
}

/// Provides alarm distances and labels in the units the device is set to —
/// kilometres for metric locales, miles for the UK and US.
enum AlarmDistances {

    static var usesMetric: Bool {
        Locale.current.measurementSystem == .metric
    }

    static var options: [AlarmDistanceOption] {
        if usesMetric {
            return [
                AlarmDistanceOption(metres: 500, label: "500 m away"),
                AlarmDistanceOption(metres: 1000, label: "1 km away"),
                AlarmDistanceOption(metres: 2000, label: "2 km away"),
                AlarmDistanceOption(metres: 3000, label: "3 km away"),
            ]
        }
        return [
            AlarmDistanceOption(metres: 402.336, label: "¼ mile away"),
            AlarmDistanceOption(metres: 804.672, label: "½ mile away"),
            AlarmDistanceOption(metres: 1609.344, label: "1 mile away"),
            AlarmDistanceOption(metres: 3218.688, label: "2 miles away"),
        ]
    }

    /// Compact label for an arbitrary metre value, in the device's units.
    static func shortLabel(forMetres metres: Double) -> String {
        if usesMetric {
            return metres >= 1000
                ? String(format: "%.0f km", metres / 1000)
                : String(format: "%.0f m", metres)
        }
        let miles = metres / 1609.344
        if abs(miles - 0.25) < 0.05 { return "¼ mile" }
        if abs(miles - 0.5) < 0.05 { return "½ mile" }
        if abs(miles - 1) < 0.25 { return "1 mile" }
        return String(format: "%.0f miles", miles.rounded())
    }
}

/// An active "tell me when this bus is near" alarm. The reference point is
/// What kind of arrival the alarm watches for.
enum AlarmKind: String, Codable, Hashable {
    /// The bus comes within a chosen distance of where the user set it.
    case proximity
    /// The bus reaches a specific stop (e.g. a parent watching a public bus
    /// reach a stop — it follows the bus, not any person).
    case stopArrival
}

/// where the user was standing when they set it (e.g. their stop), so the
/// alarm is stable even if they move around while waiting.
struct BusAlarm: Identifiable, Codable, Hashable {
    var id: String
    var kind: AlarmKind
    var vehicleID: Int
    var serviceID: Int?
    var lineName: String
    var destination: String?
    var thresholdMetres: Double
    var referenceLatitude: Double
    var referenceLongitude: Double
    /// Stop name for `.stopArrival` alarms.
    var targetName: String?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         kind: AlarmKind = .proximity,
         vehicleID: Int,
         serviceID: Int?,
         lineName: String,
         destination: String?,
         thresholdMetres: Double,
         reference: CLLocationCoordinate2D,
         targetName: String? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.vehicleID = vehicleID
        self.serviceID = serviceID
        self.lineName = lineName
        self.destination = destination
        self.thresholdMetres = thresholdMetres
        self.referenceLatitude = reference.latitude
        self.referenceLongitude = reference.longitude
        self.targetName = targetName
        self.createdAt = createdAt
    }

    var referenceLocation: CLLocation {
        CLLocation(latitude: referenceLatitude, longitude: referenceLongitude)
    }

    var distanceShortLabel: String {
        AlarmDistances.shortLabel(forMetres: thresholdMetres)
    }
}
