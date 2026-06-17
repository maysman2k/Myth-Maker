import Foundation

/// Transforms a saved timetable's journeys into the classic printed-timetable
/// grid: stops down the side, journeys across the top, grouped by direction.
/// Pure logic so it can be unit-tested without UI.
enum TimetableGrid {

    struct StopRow: Identifiable, Equatable {
        let atco: String
        let name: String
        var id: String { atco }
    }

    struct Column: Identifiable, Equatable {
        /// Trip id.
        let id: Int
        /// Seconds-after-midnight at each stop row; nil where the journey
        /// doesn't call.
        let times: [Int?]

        var startSeconds: Int? { times.compactMap { $0 }.first }
    }

    struct Direction: Identifiable, Equatable {
        let heading: String
        let stops: [StopRow]
        let columns: [Column]

        var id: String { heading }
    }

    /// One grid per direction. Direction is grouped by trip headsign; within a
    /// direction the longest journey defines the stop order, and each journey
    /// becomes a column with a time (or blank) against every stop.
    static func directions(from trips: [TimetableTrip]) -> [Direction] {
        let groups = Dictionary(grouping: trips.filter { !$0.times.isEmpty }) {
            $0.headsign?.trimmingCharacters(in: .whitespaces).isEmpty == false
                ? $0.headsign! : "Journeys"
        }

        return groups.map { heading, groupTrips in
            let ordered = groupTrips.sorted { ($0.startSeconds ?? 0) < ($1.startSeconds ?? 0) }
            // Use the most complete journey as the row template.
            let template = ordered.max { $0.times.count < $1.times.count } ?? ordered[0]
            let stops = template.times.enumerated().map { index, time in
                StopRow(atco: time.atcoCode ?? "row-\(index)",
                        name: time.stopName ?? time.atcoCode ?? "Stop")
            }
            var stopIndex: [String: Int] = [:]
            for (index, stop) in stops.enumerated() where stopIndex[stop.atco] == nil {
                stopIndex[stop.atco] = index
            }

            let columns = ordered.map { trip -> Column in
                var row = [Int?](repeating: nil, count: stops.count)
                for time in trip.times {
                    if let atco = time.atcoCode, let index = stopIndex[atco] {
                        row[index] = time.departureSeconds ?? time.arrivalSeconds
                    }
                }
                return Column(id: trip.id, times: row)
            }
            return Direction(heading: heading, stops: stops, columns: columns)
        }
        // Busiest direction first.
        .sorted { $0.columns.count > $1.columns.count }
    }
}
