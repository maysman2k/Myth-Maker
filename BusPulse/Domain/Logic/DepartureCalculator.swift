import Foundation

/// Builds a departure board for a stop from cached timetables — works
/// completely offline. Pure logic, fully unit-tested.
enum DepartureCalculator {

    /// Next departures at `atcoCode` across the given timetables.
    ///
    /// Each timetable carries the operating date its trips were fetched for;
    /// past-midnight times (>= 24:00) resolve onto the following calendar day
    /// automatically because times are seconds after that day's start.
    static func nextDepartures(at atcoCode: String,
                               from timetables: [CachedTimetable],
                               after now: Date,
                               limit: Int = 12,
                               calendar: Calendar = .current) -> [Departure] {
        var departures: [Departure] = []

        for timetable in timetables {
            let dayStart = calendar.startOfDay(for: timetable.date)
            for trip in timetable.trips {
                guard let stopTime = trip.times.first(where: { $0.atcoCode == atcoCode }),
                      let seconds = stopTime.departureSeconds ?? stopTime.arrivalSeconds else {
                    continue
                }
                let departureDate = TimeOfDay.date(forSeconds: seconds, onDayStarting: dayStart)
                guard departureDate >= now else { continue }
                departures.append(Departure(tripID: trip.id,
                                            lineName: timetable.service.lineName,
                                            destination: trip.headsign ?? trip.times.last?.stopName,
                                            departure: departureDate))
            }
        }

        return Array(departures.sorted { $0.departure < $1.departure }.prefix(limit))
    }

    /// "Due", "3 min", or a clock time for anything further out.
    static func countdownLabel(to departure: Date, from now: Date) -> String {
        let seconds = departure.timeIntervalSince(now)
        if seconds < 60 { return "Due" }
        let minutes = Int(seconds / 60)
        if minutes <= 59 { return "\(minutes) min" }
        return departure.formatted(date: .omitted, time: .shortened)
    }
}
