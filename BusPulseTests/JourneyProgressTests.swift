import CoreLocation
import XCTest
@testable import BusPulse

final class JourneyProgressTests: XCTestCase {

    private let dayStart = Calendar.current.startOfDay(for: .now)

    private func stop(_ name: String, lat: Double, lon: Double, seconds: Int) -> TimetableStopTime {
        TimetableStopTime(atcoCode: name, stopName: name,
                          departureSeconds: seconds, arrivalSeconds: nil,
                          latitude: lat, longitude: lon)
    }

    func testAnchorsAtNearestStopAndEstimatesFromSchedule() {
        // Three stops 10 minutes apart in schedule.
        let times = [
            stop("Alpha", lat: 54.0, lon: -1.0, seconds: 25_200),   // 07:00
            stop("Bravo", lat: 54.1, lon: -1.0, seconds: 25_800),   // 07:10
            stop("Charlie", lat: 54.2, lon: -1.0, seconds: 26_400), // 07:20
        ]
        let now = Date.now
        // Bus is sitting at Bravo.
        let result = try! XCTUnwrap(JourneyProgress.compute(
            times: times,
            busCoordinate: CLLocationCoordinate2D(latitude: 54.1, longitude: -1.0),
            now: now, dayStart: dayStart))

        XCTAssertEqual(result.passedCount, 1, "Alpha already passed")
        XCTAssertEqual(result.upcoming.map(\.name), ["Bravo", "Charlie"])
        XCTAssertTrue(result.upcoming.first?.isNext ?? false)
        // Bravo is due ~now; Charlie ~10 minutes later.
        XCTAssertEqual(result.upcoming[0].eta.timeIntervalSince(now), 0, accuracy: 1)
        XCTAssertEqual(result.upcoming[1].eta.timeIntervalSince(now), 600, accuracy: 1)
    }

    func testLatenessIsBakedInByAnchoringAtNow() {
        // Whatever the scheduled time, the nearest stop is treated as "now",
        // so a bus running late still gives forward-looking ETAs.
        let times = [
            stop("Alpha", lat: 54.0, lon: -1.0, seconds: 0),
            stop("Bravo", lat: 54.1, lon: -1.0, seconds: 300),
        ]
        let now = Date.now
        let result = try! XCTUnwrap(JourneyProgress.compute(
            times: times,
            busCoordinate: CLLocationCoordinate2D(latitude: 54.0, longitude: -1.0),
            now: now, dayStart: dayStart))
        XCTAssertEqual(result.upcoming[0].eta.timeIntervalSince(now), 0, accuracy: 1)
        XCTAssertEqual(result.upcoming[1].eta.timeIntervalSince(now), 300, accuracy: 1)
    }

    func testEmptyTimesReturnsNil() {
        XCTAssertNil(JourneyProgress.compute(times: [], busCoordinate: nil,
                                             now: .now, dayStart: dayStart))
    }
}
