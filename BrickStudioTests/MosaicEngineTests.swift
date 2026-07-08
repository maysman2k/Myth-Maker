import XCTest
@testable import BrickStudio

final class MosaicEngineTests: XCTestCase {
    func testNearestColourPicksExactMatch() {
        let red = RGB(r: 180, g: 0, b: 0)
        let match = MosaicEngine.nearestColour(to: red, in: BrickPalette.limited)
        XCTAssertEqual(match.name, "Red")
    }

    func testNearestColourPicksClosestNeighbour() {
        let nearlyWhite = RGB(r: 240, g: 240, b: 238)
        let match = MosaicEngine.nearestColour(to: nearlyWhite, in: BrickPalette.limited)
        XCTAssertEqual(match.name, "White")
    }

    func testLuminanceMatchingMapsColourToTone() {
        // A saturated red has mid luminance and should land on a mid grey,
        // not black or white, in black-and-white mode.
        let red = RGB(r: 200, g: 30, b: 30)
        let match = MosaicEngine.nearestColour(to: red, in: BrickPalette.blackAndWhite, matchLuminance: true)
        XCTAssertTrue(["Dark Grey", "Grey"].contains(match.name), "Got \(match.name)")
    }

    func testMapGridUsesSelectedPalette() {
        let grid = [
            [RGB(r: 0, g: 0, b: 0), RGB(r: 255, g: 255, b: 255)],
            [RGB(r: 180, g: 0, b: 0), RGB(r: 30, g: 90, b: 168)]
        ]
        let mapped = MosaicEngine.mapGrid(grid, mode: .limitedPalette)
        XCTAssertEqual(mapped[0][0].name, "Black")
        XCTAssertEqual(mapped[0][1].name, "White")
        XCTAssertEqual(mapped[1][0].name, "Red")
        XCTAssertEqual(mapped[1][1].name, "Blue")
    }

    func testEstimateCountsBricksAndColours() {
        let black = BrickPalette.limited[0]
        let white = BrickPalette.limited[1]
        let mapped = [
            [black, white, black],
            [white, black, white]
        ]
        let estimate = MosaicEngine.estimate(for: mapped)
        XCTAssertEqual(estimate.brickCount, 6)
        XCTAssertEqual(estimate.colourCount, 2)
        XCTAssertEqual(estimate.difficulty, .beginner)
    }

    func testDifficultyBands() {
        XCTAssertEqual(MosaicEngine.difficulty(brickCount: 32 * 32, colourCount: 5), .beginner)
        XCTAssertEqual(MosaicEngine.difficulty(brickCount: 32 * 32, colourCount: 14), .intermediate)
        XCTAssertEqual(MosaicEngine.difficulty(brickCount: 48 * 48, colourCount: 6), .intermediate)
        XCTAssertEqual(MosaicEngine.difficulty(brickCount: 64 * 64, colourCount: 16), .advanced)
    }

    func testGridSizesMatchSpec() {
        XCTAssertEqual(MosaicSize.small.studs.width, 32)
        XCTAssertEqual(MosaicSize.medium.studs.width, 48)
        XCTAssertEqual(MosaicSize.large.studs.width, 64)
    }
}
