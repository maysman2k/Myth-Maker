import CoreLocation
import XCTest
@testable import BusPulse

final class VehiclePrioritiserTests: XCTestCase {

    private let centre = CLLocationCoordinate2D(latitude: 54.9783, longitude: -1.6178)

    /// Builds a vehicle a given number of metres east of the centre.
    private func vehicle(id: Int, serviceID: Int?, metresEast: Double) -> VehiclePosition {
        let lonOffset = metresEast / (111_111 * cos(centre.latitude * .pi / 180))
        return VehiclePosition(id: id, serviceID: serviceID,
                               latitude: centre.latitude,
                               longitude: centre.longitude + lonOffset,
                               lineName: "\(id)")
    }

    func testCapsToLimitByDistance() {
        let vehicles = (1...30).map { vehicle(id: $0, serviceID: $0, metresEast: Double($0) * 100) }
        let result = VehiclePrioritiser.prioritised(vehicles, favouriteServiceIDs: [],
                                                    near: centre, limit: 10)
        XCTAssertEqual(result.count, 10)
        // Closest (smallest offset) come first.
        XCTAssertEqual(result.map(\.id), Array(1...10))
    }

    func testFavouritesTakePriorityOverCloserNonFavourites() {
        // A far favourite (service 99) should still beat near non-favourites.
        var vehicles = (1...10).map { vehicle(id: $0, serviceID: $0, metresEast: Double($0) * 100) }
        vehicles.append(vehicle(id: 99, serviceID: 99, metresEast: 5000))
        let result = VehiclePrioritiser.prioritised(vehicles, favouriteServiceIDs: [99],
                                                    near: centre, limit: 10)
        XCTAssertEqual(result.first?.id, 99, "Favourite shown first despite being farthest")
        XCTAssertEqual(result.count, 10)
    }

    func testMoreThanLimitFavouritesShowsOnlyClosestFavourites() {
        let favourites = (1...15).map { vehicle(id: $0, serviceID: $0, metresEast: Double($0) * 100) }
        let others = (100...110).map { vehicle(id: $0, serviceID: $0, metresEast: 10) }
        let favIDs = Set(1...15)
        let result = VehiclePrioritiser.prioritised(favourites + others,
                                                    favouriteServiceIDs: favIDs,
                                                    near: centre, limit: 10)
        XCTAssertEqual(result.count, 10)
        XCTAssertTrue(result.allSatisfy { favIDs.contains($0.serviceID ?? -1) },
                      "When favourites overflow, no non-favourites are shown")
        XCTAssertEqual(result.map(\.id), Array(1...10), "Closest 10 favourites")
    }

    func testFewerThanLimitReturnsAll() {
        let vehicles = (1...5).map { vehicle(id: $0, serviceID: $0, metresEast: Double($0) * 100) }
        let result = VehiclePrioritiser.prioritised(vehicles, favouriteServiceIDs: [],
                                                    near: centre, limit: 10)
        XCTAssertEqual(result.count, 5)
    }
}
