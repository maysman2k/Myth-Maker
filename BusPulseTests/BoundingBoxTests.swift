import CoreLocation
import MapKit
import XCTest
@testable import BusPulse

final class BoundingBoxTests: XCTestCase {

    func testNormalisesSwappedCorners() {
        let box = BoundingBox(minLongitude: -2.0, minLatitude: 53.6,
                              maxLongitude: -2.4, maxLatitude: 53.4)
        XCTAssertLessThan(box.minLongitude, box.maxLongitude)
        XCTAssertLessThan(box.minLatitude, box.maxLatitude)
    }

    func testClampPreservesCentreAndCapsArea() {
        // 1 degree square — far over the 0.15 limit the stops endpoint allows.
        let box = BoundingBox(minLongitude: -3.0, minLatitude: 53.0,
                              maxLongitude: -2.0, maxLatitude: 54.0)
        let clamped = box.clamped()

        XCTAssertLessThanOrEqual(clamped.area, BoundingBox.maximumStopQueryArea + 0.0001)
        XCTAssertEqual(clamped.center.latitude, box.center.latitude, accuracy: 0.0001)
        XCTAssertEqual(clamped.center.longitude, box.center.longitude, accuracy: 0.0001)
    }

    func testClampLeavesSmallBoxesAlone() {
        let box = BoundingBox(minLongitude: -2.25, minLatitude: 53.45,
                              maxLongitude: -2.20, maxLatitude: 53.50)
        XCTAssertEqual(box.clamped(), box)
    }

    func testQueryItemsUseBustimesConvention() {
        let box = BoundingBox(minLongitude: -2.3, minLatitude: 53.4,
                              maxLongitude: -2.2, maxLatitude: 53.5)
        let names = box.queryItems.map(\.name)
        XCTAssertEqual(names, ["xmin", "ymin", "xmax", "ymax"])
        XCTAssertEqual(box.queryItems[0].value, "-2.300000")
    }

    func testContains() {
        let box = BoundingBox(minLongitude: -2.3, minLatitude: 53.4,
                              maxLongitude: -2.2, maxLatitude: 53.5)
        XCTAssertTrue(box.contains(CLLocationCoordinate2D(latitude: 53.45, longitude: -2.25)))
        XCTAssertFalse(box.contains(CLLocationCoordinate2D(latitude: 53.55, longitude: -2.25)))
    }

    func testRadiusInitialiserRoughlyMatchesRequestedSize() {
        let center = CLLocationCoordinate2D(latitude: 53.48, longitude: -2.24)
        let box = BoundingBox(center: center, radiusMetres: 1000)
        // ~1km radius → ~0.018 degrees of latitude in total span.
        XCTAssertEqual(box.maxLatitude - box.minLatitude, 0.018, accuracy: 0.002)
        XCTAssertTrue(box.contains(center))
    }
}

final class LiveryColorTests: XCTestCase {

    func testExtractsSixDigitHex() {
        XCTAssertEqual(LiveryColor.firstHex(inCSS: "#dc0000"), "#dc0000")
        XCTAssertEqual(LiveryColor.firstHex(inCSS: "linear-gradient(45deg, #1a2b3c 50%, #ffffff 50%)"),
                       "#1a2b3c")
    }

    func testExpandsShorthandHex() {
        XCTAssertEqual(LiveryColor.firstHex(inCSS: "#abc"), "#aabbcc")
    }

    func testParsesRGBFunction() {
        XCTAssertEqual(LiveryColor.firstHex(inCSS: "rgb(220, 0, 0)"), "#dc0000")
    }

    func testReturnsNilForJunk() {
        XCTAssertNil(LiveryColor.firstHex(inCSS: nil))
        XCTAssertNil(LiveryColor.firstHex(inCSS: ""))
        XCTAssertNil(LiveryColor.firstHex(inCSS: "url(stagecoach.png)"))
    }

    func testContrastingForeground() {
        XCTAssertEqual(LiveryColor.contrastingForeground(forHex: "#ffffff"), "#000000")
        XCTAssertEqual(LiveryColor.contrastingForeground(forHex: "#1a1a1a"), "#ffffff")
    }
}
