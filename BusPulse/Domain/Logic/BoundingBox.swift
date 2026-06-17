import CoreLocation
import Foundation
import MapKit

/// Geographic bounding box matching the bustimes.org query convention
/// (x = longitude, y = latitude). The stops endpoint rejects boxes larger
/// than 0.15 square degrees, so boxes can clamp themselves around their centre.
struct BoundingBox: Equatable {
    var minLongitude: Double
    var minLatitude: Double
    var maxLongitude: Double
    var maxLatitude: Double

    static let maximumStopQueryArea = 0.15

    init(minLongitude: Double, minLatitude: Double, maxLongitude: Double, maxLatitude: Double) {
        self.minLongitude = min(minLongitude, maxLongitude)
        self.maxLongitude = max(minLongitude, maxLongitude)
        self.minLatitude = min(minLatitude, maxLatitude)
        self.maxLatitude = max(minLatitude, maxLatitude)
    }

    init(region: MKCoordinateRegion) {
        self.init(minLongitude: region.center.longitude - region.span.longitudeDelta / 2,
                  minLatitude: region.center.latitude - region.span.latitudeDelta / 2,
                  maxLongitude: region.center.longitude + region.span.longitudeDelta / 2,
                  maxLatitude: region.center.latitude + region.span.latitudeDelta / 2)
    }

    /// A box of roughly `radiusMetres` around a coordinate.
    init(center: CLLocationCoordinate2D, radiusMetres: Double) {
        let latDelta = radiusMetres / 111_111
        let lonDelta = radiusMetres / (111_111 * max(0.2, cos(center.latitude * .pi / 180)))
        self.init(minLongitude: center.longitude - lonDelta,
                  minLatitude: center.latitude - latDelta,
                  maxLongitude: center.longitude + lonDelta,
                  maxLatitude: center.latitude + latDelta)
    }

    /// Smallest box containing every coordinate, padded equally in metres.
    init?(coordinates: [CLLocationCoordinate2D], paddingMetres: Double = 0) {
        guard let first = coordinates.first else { return nil }

        var minLongitude = first.longitude
        var maxLongitude = first.longitude
        var minLatitude = first.latitude
        var maxLatitude = first.latitude

        for coordinate in coordinates.dropFirst() {
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
        }

        if paddingMetres > 0 {
            let centerLatitude = (minLatitude + maxLatitude) / 2
            let latPadding = paddingMetres / 111_111
            let lonPadding = paddingMetres / (111_111 * max(0.2, cos(centerLatitude * .pi / 180)))
            minLongitude -= lonPadding
            maxLongitude += lonPadding
            minLatitude -= latPadding
            maxLatitude += latPadding
        }

        self.init(minLongitude: minLongitude,
                  minLatitude: minLatitude,
                  maxLongitude: maxLongitude,
                  maxLatitude: maxLatitude)
    }

    var area: Double {
        (maxLongitude - minLongitude) * (maxLatitude - minLatitude)
    }

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2,
                               longitude: (minLongitude + maxLongitude) / 2)
    }

    /// Shrinks the box around its centre until its area is at most `maxArea`,
    /// preserving aspect ratio. Returns self when already small enough.
    func clamped(toArea maxArea: Double = BoundingBox.maximumStopQueryArea) -> BoundingBox {
        guard area > maxArea, area > 0 else { return self }
        let scale = (maxArea / area).squareRoot()
        let halfWidth = (maxLongitude - minLongitude) * scale / 2
        let halfHeight = (maxLatitude - minLatitude) * scale / 2
        let mid = center
        return BoundingBox(minLongitude: mid.longitude - halfWidth,
                           minLatitude: mid.latitude - halfHeight,
                           maxLongitude: mid.longitude + halfWidth,
                           maxLatitude: mid.latitude + halfHeight)
    }

    /// Query items in the bustimes.org convention.
    var queryItems: [URLQueryItem] {
        [URLQueryItem(name: "xmin", value: String(format: "%.6f", minLongitude)),
         URLQueryItem(name: "ymin", value: String(format: "%.6f", minLatitude)),
         URLQueryItem(name: "xmax", value: String(format: "%.6f", maxLongitude)),
         URLQueryItem(name: "ymax", value: String(format: "%.6f", maxLatitude))]
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        (minLatitude...maxLatitude).contains(coordinate.latitude)
            && (minLongitude...maxLongitude).contains(coordinate.longitude)
    }
}
