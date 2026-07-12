import UIKit
import XCTest
@testable import BrickStudio

/// The native Mosaic Maker's money maths. The server re-validates prices,
/// but the app must quote the right number in the first place.
final class MosaicPricingTests: XCTestCase {
    func testGridPricesInPence() {
        XCTAssertEqual(MosaicGrid.small.price, 10_500)   // £105
        XCTAssertEqual(MosaicGrid.medium.price, 19_500)  // £195
        XCTAssertEqual(MosaicGrid.large.price, 29_500)   // £295
    }

    func testPricesRiseWithSize() {
        let prices = MosaicGrid.allCases.sorted { $0.rawValue < $1.rawValue }.map(\.price)
        XCTAssertEqual(prices, prices.sorted(), "A bigger mosaic must never be cheaper than a smaller one")
    }

    func testGridSizesMatchProductTiers() {
        XCTAssertEqual(MosaicGrid.small.rawValue, 32)
        XCTAssertEqual(MosaicGrid.medium.rawValue, 48)
        XCTAssertEqual(MosaicGrid.large.rawValue, 64)
    }

    func testTotalBricksIsGridSquared() {
        let result = MosaicResult(gridSize: 48, price: MosaicGrid.medium.price, preview: UIImage(), parts: [], ldraw: "")
        XCTAssertEqual(result.totalBricks, 48 * 48)
        XCTAssertEqual(result.gridLabel, "48 x 48")
    }

    func testMosaicPartIdentityIsStable() {
        let part = MosaicPart(colour: "Red", elementID: "300121", ldrawCode: 4, quantity: 12)
        XCTAssertEqual(part.id, "Red-300121")
    }
}
