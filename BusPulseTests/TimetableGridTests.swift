import XCTest
@testable import BusPulse

final class TimetableGridTests: XCTestCase {

    private func trip(id: Int, headsign: String,
                      stops: [(atco: String, name: String, seconds: Int)]) -> TimetableTrip {
        TimetableTrip(id: id, headsign: headsign,
                      times: stops.map { TimetableStopTime(atcoCode: $0.atco, stopName: $0.name,
                                                           departureSeconds: $0.seconds,
                                                           arrivalSeconds: nil) })
    }

    func testGroupsByDirectionAndOrdersStopsByLongestJourney() {
        let trips = [
            trip(id: 1, headsign: "Blyth", stops: [("A", "Alpha", 25_200), ("B", "Bravo", 25_500)]),
            trip(id: 2, headsign: "Blyth", stops: [("A", "Alpha", 28_800), ("B", "Bravo", 29_100), ("C", "Charlie", 29_400)]),
            trip(id: 3, headsign: "Newcastle", stops: [("C", "Charlie", 32_400), ("A", "Alpha", 33_000)]),
        ]

        let directions = TimetableGrid.directions(from: trips)
        XCTAssertEqual(directions.count, 2)

        let blyth = try! XCTUnwrap(directions.first { $0.heading == "Blyth" })
        // Longest journey (trip 2, 3 stops) sets row order.
        XCTAssertEqual(blyth.stops.map(\.name), ["Alpha", "Bravo", "Charlie"])
        XCTAssertEqual(blyth.columns.count, 2)
        // Columns sorted by start time: trip 1 then trip 2.
        XCTAssertEqual(blyth.columns.map(\.id), [1, 2])
    }

    func testColumnsLeaveBlankWhereAJourneySkipsAStop() {
        let trips = [
            trip(id: 1, headsign: "Town", stops: [("A", "Alpha", 25_200), ("B", "Bravo", 25_500), ("C", "Charlie", 25_800)]),
            trip(id: 2, headsign: "Town", stops: [("A", "Alpha", 28_800), ("C", "Charlie", 29_400)]),
        ]

        let direction = TimetableGrid.directions(from: trips)[0]
        let skipping = try! XCTUnwrap(direction.columns.first { $0.id == 2 })
        // Bravo (row index 1) is blank for the journey that skips it.
        XCTAssertNil(skipping.times[1])
        XCTAssertEqual(skipping.times[0], 28_800)
        XCTAssertEqual(skipping.times[2], 29_400)
    }

    func testIgnoresEmptyJourneys() {
        let trips = [
            TimetableTrip(id: 9, headsign: "Nowhere", times: []),
            trip(id: 1, headsign: "Town", stops: [("A", "Alpha", 25_200)]),
        ]
        let directions = TimetableGrid.directions(from: trips)
        XCTAssertEqual(directions.count, 1)
        XCTAssertEqual(directions[0].heading, "Town")
    }
}
