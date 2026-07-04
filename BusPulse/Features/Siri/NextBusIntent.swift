import AppIntents
import CoreLocation
import Foundation

/// "Hey Siri, next X8 bus" — finds the nearest stop on the given route and
/// speaks its next couple of departures. Self-contained so it runs from Siri,
/// Spotlight or the Shortcuts app without launching the full UI.
struct NextBusIntent: AppIntent {
    static var title: LocalizedStringResource = "Next bus on a route"
    static var description = IntentDescription(
        "Find the next departures for a bus route from your nearest stop.")
    static var openAppWhenRun = false

    @Parameter(title: "Route", requestValueDialog: "Which bus route? For example, X8.")
    var route: String

    static var parameterSummary: some ParameterSummary {
        Summary("Next \(\.$route) bus")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinate = try await Self.currentLocation()
        let api = BusTimesAPI(baseURL: AppConfig.serverURL)

        guard let service = try await api.services(matching: route, near: coordinate).first else {
            return .result(dialog: "I couldn't find a bus route called \(route).")
        }

        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let stops = try await api.stops(onService: service.id)
        guard let nearest = stops.min(by: {
            here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                < here.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }) else {
            return .result(dialog: "I couldn't find any stops for the \(service.lineName).")
        }

        let trips = try await api.trips(serviceID: service.id, date: Date())
        let nowSeconds = Self.nowSecondsUK()
        let upcoming = trips
            .compactMap { $0.times.first(where: { $0.atcoCode == nearest.id })?.departureSeconds }
            .filter { $0 >= nowSeconds }
            .sorted()
            .prefix(2)
            .map { TimeOfDay.clock(forSeconds: $0) }

        guard !upcoming.isEmpty else {
            return .result(dialog: "There are no more \(service.lineName) buses from \(nearest.name) today.")
        }
        let times = upcoming.joined(separator: ", then ")
        return .result(dialog: "The next \(service.lineName) from \(nearest.name) is at \(times).")
    }

    /// One-shot current location via the iOS 17 async location stream, racing
    /// against a timeout so the intent can't hang if no fix arrives.
    static func currentLocation() async throws -> CLLocationCoordinate2D {
        try await withThrowingTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location { return location.coordinate }
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(for: .seconds(8))
                return nil
            }
            let first = try await group.next() ?? nil
            group.cancelAll()
            guard let coordinate = first else { throw NextBusError.locationUnavailable }
            return coordinate
        }
    }

    /// Seconds since midnight in UK local time (matches timetable clock).
    static func nowSecondsUK() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let parts = calendar.dateComponents([.hour, .minute, .second], from: Date())
        return (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0)
    }
}

enum NextBusError: Error, CustomLocalizedStringResourceConvertible {
    case locationUnavailable
    var localizedStringResource: LocalizedStringResource {
        "I need your location to find the nearest stop. Turn on location access for Wait Less."
    }
}

/// Registers the Siri phrases so "next X8 bus" works without any Shortcuts
/// setup by the user.
struct BusPulseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextBusIntent(),
            phrases: [
                "Next \(.applicationName) bus",
                "Next bus on \(.applicationName)",
                "When's my next bus on \(.applicationName)",
                "When's the next bus with \(.applicationName)",
                "Ask \(.applicationName) for my next bus",
                "\(.applicationName) next bus",
            ],
            shortTitle: "Next bus",
            systemImageName: "bus.fill")
    }
}
