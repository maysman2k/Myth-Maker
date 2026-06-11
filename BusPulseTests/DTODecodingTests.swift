import XCTest
@testable import BusPulse

/// Decoding tests against realistic feed fixtures, including the shape
/// variations the aggregated feeds are known for (heading as a string,
/// missing fields, alternative key names).
final class DTODecodingTests: XCTestCase {

    private let decoder = JSONDecoder()

    func testDecodesVehicleWithNumericHeading() throws {
        let json = """
        {
          "id": 12345,
          "journey_id": 9876,
          "service_id": 1234,
          "trip_id": 4321,
          "coordinates": [-2.2426, 53.4808],
          "heading": 270,
          "datetime": "2026-06-11T09:30:00.000Z",
          "destination": "Piccadilly Gardens",
          "service": {"line_name": "43", "url": "/services/43-manchester"},
          "vehicle": {"name": "1234 - YX19 ABC", "url": "/vehicles/abc-1234",
                      "css": "linear-gradient(#dc0000, #990000)", "text_colour": "#ffffff"},
          "delay": 120
        }
        """
        let item = try decoder.decode(VehicleJSONItem.self, from: Data(json.utf8))
        let vehicle = try XCTUnwrap(item.toDomain())

        XCTAssertEqual(vehicle.id, 12345)
        XCTAssertEqual(vehicle.latitude, 53.4808, accuracy: 0.0001)
        XCTAssertEqual(vehicle.longitude, -2.2426, accuracy: 0.0001)
        XCTAssertEqual(vehicle.heading, 270)
        XCTAssertEqual(vehicle.lineName, "43")
        XCTAssertEqual(vehicle.destination, "Piccadilly Gardens")
        XCTAssertEqual(vehicle.liveryBackground, "#dc0000")
        XCTAssertEqual(vehicle.liveryForeground, "#ffffff")
        XCTAssertEqual(vehicle.delaySeconds, 120)
        XCTAssertNotNil(vehicle.recordedAt)
        XCTAssertEqual(vehicle.webURL?.absoluteString, "https://bustimes.org/vehicles/abc-1234")
    }

    func testDecodesVehicleWithStringHeadingAndSparseFields() throws {
        let json = """
        {
          "id": 777,
          "coordinates": [-0.1276, 51.5072],
          "heading": "45",
          "service": {"line_name": "N25"}
        }
        """
        let item = try decoder.decode(VehicleJSONItem.self, from: Data(json.utf8))
        let vehicle = try XCTUnwrap(item.toDomain())

        XCTAssertEqual(vehicle.heading, 45)
        XCTAssertEqual(vehicle.lineName, "N25")
        XCTAssertNil(vehicle.delaySeconds)
        XCTAssertNil(vehicle.liveryBackground)
    }

    func testVehicleWithoutCoordinatesIsDropped() throws {
        let json = """
        {"id": 1, "coordinates": []}
        """
        let item = try decoder.decode(VehicleJSONItem.self, from: Data(json.utf8))
        XCTAssertNil(item.toDomain())
    }

    func testDecodesStopsGeoJSON() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {"type": "Point", "coordinates": [-2.236, 53.477]},
              "properties": {
                "name": "Oxford Road Station",
                "indicator": "Stop B",
                "bearing": 135,
                "url": "/stops/1800SB05841",
                "services": ["41", "42", "142"]
              }
            }
          ]
        }
        """
        let geo = try decoder.decode(StopsGeoJSON.self, from: Data(json.utf8))
        let stop = try XCTUnwrap(geo.features.first?.toDomain())

        XCTAssertEqual(stop.id, "1800SB05841")
        XCTAssertEqual(stop.name, "Oxford Road Station")
        XCTAssertEqual(stop.indicator, "Stop B")
        XCTAssertEqual(stop.bearing, 135)
        XCTAssertEqual(stop.lineNames, ["41", "42", "142"])
        XCTAssertEqual(stop.latitude, 53.477, accuracy: 0.0001)
    }

    func testDecodesTripTimesWithAlternativeKeys() throws {
        let aimed = """
        {
          "id": 555,
          "headsign": "Airport",
          "times": [
            {"stop": {"atco_code": "1800X1", "name": "First Stop"},
             "aimed_departure_time": "07:05:00"},
            {"stop": {"atco_code": "1800X2", "name": "Last Stop"},
             "aimed_arrival_time": "24:10:00"}
          ]
        }
        """
        let trip = try decoder.decode(TripDTO.self, from: Data(aimed.utf8)).toDomain()

        XCTAssertEqual(trip.times.count, 2)
        XCTAssertEqual(trip.times[0].atcoCode, "1800X1")
        XCTAssertEqual(trip.times[0].departureSeconds, 7 * 3600 + 5 * 60)
        XCTAssertEqual(trip.times[1].arrivalSeconds, 24 * 3600 + 10 * 60,
                       "Past-midnight times survive decoding")
        XCTAssertEqual(trip.startSeconds, 7 * 3600 + 5 * 60)
    }

    func testDecodesServiceGeometryBothShapes() throws {
        let multi = """
        {"geometry": {"type": "MultiLineString",
                      "coordinates": [[[-2.1, 53.1], [-2.2, 53.2]], [[-2.3, 53.3], [-2.4, 53.4]]]}}
        """
        let single = """
        {"geometry": {"type": "LineString", "coordinates": [[-2.1, 53.1], [-2.2, 53.2]]}}
        """
        let multiDTO = try decoder.decode(ServiceGeometryDTO.self, from: Data(multi.utf8))
        let singleDTO = try decoder.decode(ServiceGeometryDTO.self, from: Data(single.utf8))

        XCTAssertEqual(multiDTO.geometry?.lineStrings.count, 2)
        XCTAssertEqual(singleDTO.geometry?.lineStrings.count, 1)
        XCTAssertEqual(singleDTO.geometry?.lineStrings.first?.count, 2)
    }

    func testDecodesCursorPaginatedPage() throws {
        let json = """
        {"results": [{"id": 1, "slug": "43-x", "line_name": "43",
                      "description": "Town - Airport", "mode": "bus"}],
         "next": "https://bustimes.org/api/services/?cursor=abc"}
        """
        let page = try decoder.decode(APIPage<ServiceDTO>.self, from: Data(json.utf8))
        XCTAssertEqual(page.results.first?.toDomain().lineName, "43")
        XCTAssertNotNil(page.next)
    }
}
