import Foundation

// MARK: - Tolerant decoding helpers
// Live feeds aggregated from dozens of operators are not perfectly uniform,
// so every DTO decodes defensively: unexpected shapes degrade to nil rather
// than failing the whole payload.

/// Decodes a number that may arrive as Double, Int or String.
struct FlexibleDouble: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = Double(string)
        } else {
            value = nil
        }
    }
}

/// Cursor-paginated DRF response.
struct APIPage<T: Decodable>: Decodable {
    let results: [T]
    let next: String?
}

// MARK: - vehicles.json

struct VehicleJSONItem: Decodable {
    let id: Int
    let journeyID: Int?
    let serviceID: Int?
    let tripID: Int?
    let coordinates: [Double]
    let heading: Double?
    let datetime: String?
    let destination: String?
    let serviceLineName: String?
    let serviceURL: String?
    let vehicleName: String?
    let vehicleURL: String?
    let liveryCSS: String?
    let textColour: String?
    let delay: Int?

    private enum CodingKeys: String, CodingKey {
        case id, coordinates, heading, direction, datetime, destination
        case journeyID = "journey_id"
        case serviceID = "service_id"
        case tripID = "trip_id"
        case service, vehicle, delay
    }

    private struct ServiceRef: Decodable {
        let line_name: String?
        let url: String?
    }

    private struct VehicleRef: Decodable {
        let name: String?
        let url: String?
        let css: String?
        let text_colour: String?
        let livery: Livery?

        struct Livery: Decodable {
            let left: String?
            let right: String?

            init(from decoder: Decoder) throws {
                // May be {"left": css, "right": css}, a bare int id, or absent.
                if let container = try? decoder.container(keyedBy: DynamicKey.self) {
                    left = try? container.decodeIfPresent(String.self, forKey: DynamicKey("left"))
                    right = try? container.decodeIfPresent(String.self, forKey: DynamicKey("right"))
                } else {
                    left = nil
                    right = nil
                }
            }
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        journeyID = try? container.decodeIfPresent(Int.self, forKey: .journeyID)
        serviceID = try? container.decodeIfPresent(Int.self, forKey: .serviceID)
        tripID = try? container.decodeIfPresent(Int.self, forKey: .tripID)
        coordinates = (try? container.decode([Double].self, forKey: .coordinates)) ?? []
        // Heading appears as "heading" or "direction", number or string.
        let headingValue = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .heading))?.value
        let directionValue = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .direction))?.value
        heading = headingValue ?? directionValue
        datetime = try? container.decodeIfPresent(String.self, forKey: .datetime)
        destination = try? container.decodeIfPresent(String.self, forKey: .destination)
        let service = try? container.decodeIfPresent(ServiceRef.self, forKey: .service)
        serviceLineName = service?.line_name
        serviceURL = service?.url
        let vehicle = try? container.decodeIfPresent(VehicleRef.self, forKey: .vehicle)
        vehicleName = vehicle?.name
        vehicleURL = vehicle?.url
        liveryCSS = vehicle?.css ?? vehicle?.livery?.left ?? vehicle?.livery?.right
        textColour = vehicle?.text_colour
        delay = try? container.decodeIfPresent(Int.self, forKey: .delay)
    }

    func toDomain() -> VehiclePosition? {
        guard coordinates.count >= 2 else { return nil }
        let background = LiveryColor.firstHex(inCSS: liveryCSS)
        let foreground = textColour
            ?? background.map { LiveryColor.contrastingForeground(forHex: $0) }
        return VehiclePosition(id: id,
                               journeyID: journeyID,
                               serviceID: serviceID,
                               tripID: tripID,
                               latitude: coordinates[1],
                               longitude: coordinates[0],
                               heading: heading,
                               recordedAt: datetime.flatMap(Self.parseDate),
                               lineName: serviceLineName,
                               destination: destination,
                               vehicleName: vehicleName,
                               vehicleURL: vehicleURL,
                               liveryBackground: background,
                               liveryForeground: foreground,
                               delaySeconds: delay)
    }

    /// Feed timestamps appear both with and without fractional seconds.
    private static func parseDate(_ string: String) -> Date? {
        Self.fractionalParser.date(from: string) ?? Self.plainParser.date(from: string)
    }

    private static let fractionalParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - stops.json (GeoJSON)

struct StopsGeoJSON: Decodable {
    let features: [Feature]

    struct Feature: Decodable {
        let geometry: Geometry?
        let properties: Properties?

        struct Geometry: Decodable {
            let coordinates: [Double]?
        }

        struct Properties: Decodable {
            let name: String?
            let indicator: String?
            let bearing: FlexibleDouble?
            let url: String?
            let services: [String]?
        }

        func toDomain() -> Stop? {
            guard let coords = geometry?.coordinates, coords.count >= 2,
                  let url = properties?.url else { return nil }
            // URL is "/stops/{atco_code}".
            let atco = url.split(separator: "/").last.map(String.init) ?? url
            return Stop(id: atco,
                        name: properties?.name ?? "Stop",
                        indicator: properties?.indicator,
                        bearing: properties?.bearing?.value,
                        latitude: coords[1],
                        longitude: coords[0],
                        lineNames: properties?.services ?? [])
        }
    }
}

// MARK: - /api/stops/

struct StopDTO: Decodable {
    let atco_code: String
    let naptan_code: String?
    let common_name: String?
    let name: String?
    let long_name: String?
    let location: [Double]?
    let indicator: String?
    let bearing: FlexibleDouble?
    let line_names: [String]?

    func toDomain() -> Stop? {
        guard let location, location.count >= 2 else { return nil }
        return Stop(id: atco_code,
                    name: long_name ?? name ?? common_name ?? atco_code,
                    indicator: indicator,
                    bearing: bearing?.value,
                    latitude: location[1],
                    longitude: location[0],
                    lineNames: line_names ?? [],
                    naptanCode: naptan_code)
    }
}

// MARK: - /api/services/

struct ServiceDTO: Decodable {
    let id: Int
    let slug: String?
    let line_name: String?
    let description: String?
    let mode: String?

    func toDomain() -> Service {
        Service(id: id,
                lineName: line_name ?? "?",
                description: description ?? "",
                mode: mode,
                slug: slug)
    }
}

// MARK: - /api/trips/

struct TripDTO: Decodable {
    let id: Int
    let headsign: String?
    let times: [TripTimeDTO]?

    func toDomain() -> TimetableTrip {
        TimetableTrip(id: id,
                      headsign: headsign,
                      times: (times ?? []).map { $0.toDomain() })
    }
}

struct TripTimeDTO: Decodable {
    let stopATCO: String?
    let stopName: String?
    let aimedArrival: String?
    let aimedDeparture: String?

    private enum CodingKeys: String, CodingKey {
        case stop
        case aimed_arrival_time, aimed_departure_time, arrival, departure
    }

    let latitude: Double?
    let longitude: Double?

    private struct StopRef: Decodable {
        let atco_code: String?
        let name: String?
        let common_name: String?
        let location: [Double]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // "stop" may be an object or a bare ATCO string.
        if let ref = try? container.decodeIfPresent(StopRef.self, forKey: .stop) {
            stopATCO = ref.atco_code
            stopName = ref.name ?? ref.common_name
            if let location = ref.location, location.count >= 2 {
                longitude = location[0]
                latitude = location[1]
            } else {
                latitude = nil
                longitude = nil
            }
        } else if let code = try? container.decodeIfPresent(String.self, forKey: .stop) {
            stopATCO = code
            stopName = nil
            latitude = nil
            longitude = nil
        } else {
            stopATCO = nil
            stopName = nil
            latitude = nil
            longitude = nil
        }
        aimedArrival = (try? container.decodeIfPresent(String.self, forKey: .aimed_arrival_time))
            ?? (try? container.decodeIfPresent(String.self, forKey: .arrival)) ?? nil
        aimedDeparture = (try? container.decodeIfPresent(String.self, forKey: .aimed_departure_time))
            ?? (try? container.decodeIfPresent(String.self, forKey: .departure)) ?? nil
    }

    func toDomain() -> TimetableStopTime {
        TimetableStopTime(atcoCode: stopATCO,
                          stopName: stopName,
                          departureSeconds: TimeOfDay.seconds(from: aimedDeparture),
                          arrivalSeconds: TimeOfDay.seconds(from: aimedArrival),
                          latitude: latitude,
                          longitude: longitude)
    }
}

// MARK: - /api/journey (direct buses)

struct JourneyResponseDTO: Decodable {
    let options: [JourneyOptionDTO]
}

struct JourneyOptionDTO: Decodable {
    let service: ServiceDTO
    let from: StopRefDTO
    let to: StopRefDTO
    let departures: [String]

    struct StopRefDTO: Decodable {
        let atco: String?
        let name: String?
        let walk_meters: Int?
    }

    func toDomain() -> JourneyOption {
        JourneyOption(service: service.toDomain(),
                      fromStopName: from.name ?? "Stop",
                      toStopName: to.name ?? "Stop",
                      departures: departures,
                      fromWalkMeters: from.walk_meters,
                      toWalkMeters: to.walk_meters)
    }
}

// MARK: - /services/{id}.json (route geometry, best effort)

struct ServiceGeometryDTO: Decodable {
    let geometry: Geometry?

    struct Geometry: Decodable {
        let type: String?
        // LineString: [[lon,lat]]; MultiLineString: [[[lon,lat]]]
        let lineStrings: [[[Double]]]

        private enum CodingKeys: String, CodingKey { case type, coordinates }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try? container.decodeIfPresent(String.self, forKey: .type)
            if let multi = try? container.decode([[[Double]]].self, forKey: .coordinates) {
                lineStrings = multi
            } else if let single = try? container.decode([[Double]].self, forKey: .coordinates) {
                lineStrings = [single]
            } else {
                lineStrings = []
            }
        }
    }
}
