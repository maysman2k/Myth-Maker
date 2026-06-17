import Foundation

/// Merges route-scoped vehicle results with a geographic fallback. This lets
/// us still show buses for a public line like "X7" when the live feed maps
/// them onto a sibling backend route record instead of the exact searched one.
enum RouteVehicleMatcher {

    static func merged(primary: [VehiclePosition],
                       fallback: [VehiclePosition],
                       lineNames: [String]) -> [VehiclePosition] {
        let wanted = Set(lineNames.compactMap(normalized))
        var seen = Set<Int>()
        var merged: [VehiclePosition] = []

        for vehicle in primary {
            if seen.insert(vehicle.id).inserted {
                merged.append(vehicle)
            }
        }

        for vehicle in fallback {
            guard seen.insert(vehicle.id).inserted else { continue }
            guard wanted.isEmpty || matches(vehicle, wanted: wanted) else { continue }
            merged.append(vehicle)
        }

        return merged
    }

    static func matching(_ vehicles: [VehiclePosition], lineNames: [String]) -> [VehiclePosition] {
        let wanted = Set(lineNames.compactMap(normalized))
        guard !wanted.isEmpty else { return vehicles }
        return vehicles.filter { matches($0, wanted: wanted) }
    }

    private static func matches(_ vehicle: VehiclePosition, wanted: Set<String>) -> Bool {
        guard let line = normalized(vehicle.lineName) else { return false }
        return wanted.contains(line)
    }

    private static func normalized(_ lineName: String?) -> String? {
        guard let lineName else { return nil }
        let collapsed = lineName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { !$0.isWhitespace }
        return collapsed.isEmpty ? nil : collapsed
    }
}
