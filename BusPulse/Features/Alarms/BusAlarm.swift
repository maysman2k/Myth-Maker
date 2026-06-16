import CoreLocation
import Foundation

/// Distances offered when setting a bus arrival alarm. UK-friendly miles,
/// stored internally as metres.
enum AlarmDistance: Double, CaseIterable, Identifiable {
    case quarterMile = 402.336
    case halfMile = 804.672
    case oneMile = 1609.344
    case twoMiles = 3218.688

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .quarterMile: return "¼ mile away"
        case .halfMile: return "½ mile away"
        case .oneMile: return "1 mile away"
        case .twoMiles: return "2 miles away"
        }
    }

    var shortLabel: String {
        switch self {
        case .quarterMile: return "¼ mile"
        case .halfMile: return "½ mile"
        case .oneMile: return "1 mile"
        case .twoMiles: return "2 miles"
        }
    }
}

/// An active "tell me when this bus is near" alarm. The reference point is
/// where the user was standing when they set it (e.g. their stop), so the
/// alarm is stable even if they move around while waiting.
struct BusAlarm: Identifiable, Codable, Hashable {
    var id: String
    var vehicleID: Int
    var serviceID: Int?
    var lineName: String
    var destination: String?
    var thresholdMetres: Double
    var referenceLatitude: Double
    var referenceLongitude: Double
    var createdAt: Date

    init(id: String = UUID().uuidString,
         vehicleID: Int,
         serviceID: Int?,
         lineName: String,
         destination: String?,
         thresholdMetres: Double,
         reference: CLLocationCoordinate2D,
         createdAt: Date = .now) {
        self.id = id
        self.vehicleID = vehicleID
        self.serviceID = serviceID
        self.lineName = lineName
        self.destination = destination
        self.thresholdMetres = thresholdMetres
        self.referenceLatitude = reference.latitude
        self.referenceLongitude = reference.longitude
        self.createdAt = createdAt
    }

    var referenceLocation: CLLocation {
        CLLocation(latitude: referenceLatitude, longitude: referenceLongitude)
    }

    var distanceShortLabel: String {
        AlarmDistance(rawValue: thresholdMetres)?.shortLabel
            ?? String(format: "%.1f mi", thresholdMetres / 1609.344)
    }
}
