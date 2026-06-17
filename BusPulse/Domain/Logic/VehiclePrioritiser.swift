import CoreLocation
import Foundation

/// Chooses which live buses to draw on the explore map. Rendering hundreds of
/// annotations freezes the map, so we cap it: favourited routes first, then
/// the closest others, up to a small limit.
enum VehiclePrioritiser {

    static let displayLimit = 10

    /// Returns at most `limit` vehicles, prioritising those on a favourited
    /// service, each group ordered by distance to `reference`.
    static func prioritised(_ vehicles: [VehiclePosition],
                            favouriteServiceIDs: Set<Int>,
                            near reference: CLLocationCoordinate2D,
                            limit: Int = displayLimit) -> [VehiclePosition] {
        let ref = CLLocation(latitude: reference.latitude, longitude: reference.longitude)
        func distance(_ vehicle: VehiclePosition) -> Double {
            CLLocation(latitude: vehicle.latitude, longitude: vehicle.longitude).distance(from: ref)
        }
        func isFavourite(_ vehicle: VehiclePosition) -> Bool {
            guard let id = vehicle.serviceID else { return false }
            return favouriteServiceIDs.contains(id)
        }

        let favourites = vehicles.filter(isFavourite).sorted { distance($0) < distance($1) }
        // If favourites alone fill the window, show only the closest favourites.
        if favourites.count >= limit {
            return Array(favourites.prefix(limit))
        }
        let others = vehicles.filter { !isFavourite($0) }.sorted { distance($0) < distance($1) }
        return Array((favourites + others).prefix(limit))
    }
}
