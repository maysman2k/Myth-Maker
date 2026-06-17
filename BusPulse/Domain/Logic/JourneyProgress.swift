import CoreLocation
import Foundation

/// Works out where a live bus is along its scheduled journey and estimates
/// when it will reach each remaining stop. Anchored at the bus's current
/// position (so current lateness is built in), using the timetable's typical
/// stop-to-stop durations for the rest. Pure logic, unit-tested.
enum JourneyProgress {

    struct UpcomingStop: Identifiable, Equatable {
        let name: String
        let eta: Date
        /// The imminent next stop.
        let isNext: Bool
        var id: String { "\(name)-\(Int(eta.timeIntervalSince1970))" }
    }

    struct Result: Equatable {
        let upcoming: [UpcomingStop]
        /// Stops the bus has already passed.
        let passedCount: Int
    }

    static func compute(times: [TimetableStopTime],
                        busCoordinate: CLLocationCoordinate2D?,
                        now: Date,
                        dayStart: Date,
                        calendar: Calendar = .current) -> Result? {
        guard !times.isEmpty else { return nil }

        // Anchor: the stop nearest the bus (by position). Without coordinates,
        // fall back to the last stop whose scheduled time has already passed.
        let anchor: Int
        if let busCoordinate, times.contains(where: { $0.coordinate != nil }) {
            let busLocation = CLLocation(latitude: busCoordinate.latitude,
                                         longitude: busCoordinate.longitude)
            anchor = times.enumerated()
                .compactMap { index, time -> (Int, Double)? in
                    guard let coordinate = time.coordinate else { return nil }
                    let distance = CLLocation(latitude: coordinate.latitude,
                                              longitude: coordinate.longitude).distance(from: busLocation)
                    return (index, distance)
                }
                .min { $0.1 < $1.1 }?.0 ?? 0
        } else {
            let nowSeconds = secondsSinceMidnight(now, calendar: calendar)
            anchor = times.lastIndex { ($0.departureSeconds ?? $0.arrivalSeconds).map { $0 <= nowSeconds } ?? false } ?? 0
        }

        let anchorSeconds = times[anchor].departureSeconds ?? times[anchor].arrivalSeconds
        var upcoming: [UpcomingStop] = []
        for index in anchor..<times.count {
            let time = times[index]
            guard let scheduled = time.departureSeconds ?? time.arrivalSeconds,
                  let name = time.stopName ?? time.atcoCode else { continue }
            let offset = anchorSeconds.map { Double(scheduled - $0) } ?? 0
            upcoming.append(UpcomingStop(name: name,
                                         eta: now.addingTimeInterval(max(0, offset)),
                                         isNext: index == anchor))
        }
        return Result(upcoming: upcoming, passedCount: anchor)
    }

    private static func secondsSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
    }
}
