import EventKit
import Foundation

/// Abstraction so the calendar provider can be swapped later
/// (Google Calendar, Outlook) without touching feature code.
protocol CalendarSyncing {
    func addToCalendar(_ event: Event) async throws
}

final class EventKitCalendarService: CalendarSyncing {
    func addToCalendar(_ event: Event) async throws {
        guard let start = event.startDate else { throw AppError.eventNotScheduled }

        let store = EKEventStore()
        let granted = try await store.requestWriteOnlyAccessToEvents()
        guard granted else { throw AppError.permissionDenied(feature: "your calendar") }

        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = event.title
        calendarEvent.startDate = start
        if let end = event.endDate, end > start {
            calendarEvent.endDate = end
        } else {
            calendarEvent.isAllDay = true
            calendarEvent.endDate = start
        }
        calendarEvent.location = event.locationName
        calendarEvent.notes = event.detail.isEmpty ? "Planned with Planr" : event.detail
        calendarEvent.calendar = store.defaultCalendarForNewEvents

        try store.save(calendarEvent, span: .thisEvent)
    }
}
