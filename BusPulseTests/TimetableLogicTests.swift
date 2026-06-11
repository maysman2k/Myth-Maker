import XCTest
@testable import BusPulse

final class TimeOfDayTests: XCTestCase {

    func testParsesStandardTimes() {
        XCTAssertEqual(TimeOfDay.seconds(from: "07:05:00"), 7 * 3600 + 5 * 60)
        XCTAssertEqual(TimeOfDay.seconds(from: "23:59"), 23 * 3600 + 59 * 60)
        XCTAssertEqual(TimeOfDay.seconds(from: "00:00:00"), 0)
    }

    func testParsesPastMidnightTimes() {
        // UK timetables use 24:xx / 25:xx for trips running past midnight.
        XCTAssertEqual(TimeOfDay.seconds(from: "24:15:00"), 24 * 3600 + 15 * 60)
        XCTAssertEqual(TimeOfDay.seconds(from: "25:30"), 25 * 3600 + 30 * 60)
    }

    func testRejectsMalformedTimes() {
        XCTAssertNil(TimeOfDay.seconds(from: nil))
        XCTAssertNil(TimeOfDay.seconds(from: ""))
        XCTAssertNil(TimeOfDay.seconds(from: "noon"))
        XCTAssertNil(TimeOfDay.seconds(from: "12"))
        XCTAssertNil(TimeOfDay.seconds(from: "12:99"))
        XCTAssertNil(TimeOfDay.seconds(from: "12:00:99"))
    }

    func testLabels() {
        XCTAssertEqual(TimeOfDay.label(forSeconds: 7 * 3600 + 5 * 60), "07:05")
        XCTAssertEqual(TimeOfDay.label(forSeconds: 24 * 3600 + 15 * 60), "00:15 (night)")
    }
}

final class DepartureCalculatorTests: XCTestCase {

    private let calendar = Calendar.current

    private func makeTimetable(lineName: String, date: Date,
                               trips: [(id: Int, headsign: String, atco: String, seconds: Int)]) -> CachedTimetable {
        CachedTimetable(
            service: Service(id: lineName.hashValue, lineName: lineName, description: ""),
            date: date,
            downloadedAt: date,
            trips: trips.map { trip in
                TimetableTrip(id: trip.id, headsign: trip.headsign, times: [
                    TimetableStopTime(atcoCode: trip.atco, stopName: "Stop",
                                      departureSeconds: trip.seconds, arrivalSeconds: nil),
                ])
            })
    }

    func testReturnsOnlyFutureDeparturesSorted() {
        let today = calendar.startOfDay(for: .now)
        let now = today.addingTimeInterval(10 * 3600) // 10:00
        let timetable = makeTimetable(lineName: "43", date: today, trips: [
            (1, "Town", "stopA", 9 * 3600),   // 09:00 — already gone
            (2, "Town", "stopA", 11 * 3600),  // 11:00
            (3, "Town", "stopA", 10 * 3600 + 30 * 60), // 10:30
        ])

        let departures = DepartureCalculator.nextDepartures(at: "stopA",
                                                            from: [timetable], after: now)
        XCTAssertEqual(departures.map(\.tripID), [3, 2])
    }

    func testPastMidnightTripsResolveOntoNextDay() {
        let today = calendar.startOfDay(for: .now)
        let elevenPM = today.addingTimeInterval(23 * 3600)
        let timetable = makeTimetable(lineName: "N1", date: today, trips: [
            (1, "Night service", "stopA", 24 * 3600 + 30 * 60), // 00:30 tomorrow
        ])

        let departures = DepartureCalculator.nextDepartures(at: "stopA",
                                                            from: [timetable], after: elevenPM)
        XCTAssertEqual(departures.count, 1)
        let expected = today.addingTimeInterval(24.5 * 3600)
        XCTAssertEqual(departures[0].departure, expected)
    }

    func testMergesMultipleServicesAndRespectsLimit() {
        let today = calendar.startOfDay(for: .now)
        let morning = today.addingTimeInterval(8 * 3600)
        let route43 = makeTimetable(lineName: "43", date: today, trips: (0..<10).map {
            (100 + $0, "Town", "stopA", 9 * 3600 + $0 * 600)
        })
        let routeX1 = makeTimetable(lineName: "X1", date: today, trips: [
            (200, "Airport", "stopA", 9 * 3600 + 300),
        ])

        let departures = DepartureCalculator.nextDepartures(at: "stopA",
                                                            from: [route43, routeX1],
                                                            after: morning, limit: 5)
        XCTAssertEqual(departures.count, 5)
        XCTAssertEqual(departures[1].lineName, "X1", "Interleaves services chronologically")
    }

    func testIgnoresOtherStops() {
        let today = calendar.startOfDay(for: .now)
        let timetable = makeTimetable(lineName: "43", date: today, trips: [
            (1, "Town", "stopB", 9 * 3600),
        ])
        let departures = DepartureCalculator.nextDepartures(at: "stopA",
                                                            from: [timetable],
                                                            after: today)
        XCTAssertTrue(departures.isEmpty)
    }

    func testCountdownLabels() {
        let now = Date.now
        XCTAssertEqual(DepartureCalculator.countdownLabel(to: now.addingTimeInterval(30), from: now), "Due")
        XCTAssertEqual(DepartureCalculator.countdownLabel(to: now.addingTimeInterval(3 * 60 + 10), from: now), "3 min")
    }
}

final class DelayStatusTests: XCTestCase {

    func testThresholds() {
        XCTAssertEqual(DelayStatus(delaySeconds: 0), .onTime)
        XCTAssertEqual(DelayStatus(delaySeconds: 45), .onTime)
        XCTAssertEqual(DelayStatus(delaySeconds: -45), .onTime)
        XCTAssertEqual(DelayStatus(delaySeconds: 180), .late(minutes: 3))
        XCTAssertEqual(DelayStatus(delaySeconds: -120), .early(minutes: 2))
        XCTAssertEqual(DelayStatus(delaySeconds: 60), .late(minutes: 1))
    }
}
