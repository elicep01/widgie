import EventKit
import Foundation

@MainActor
final class CalendarProvider {
    private let store = EKEventStore()
    private static var hasRequestedAccess = false

    func fetch(maxEvents: Int, timeRange: String) async -> [CalendarEventSnapshot] {
        guard await requestAccessIfNeeded() else {
            return []
        }

        let now = Date()
        let end = endDate(from: now, timeRange: timeRange)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted(by: { $0.startDate < $1.startDate })
            .prefix(max(1, maxEvents))

        return events.map {
            CalendarEventSnapshot(
                id: $0.eventIdentifier ?? UUID().uuidString,
                title: $0.title ?? "Untitled",
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay,
                calendarColorHex: nil
            )
        }
    }

    private func requestAccessIfNeeded() async -> Bool {
        if Self.hasRequestedAccess {
            return true
        }

        do {
            if #available(macOS 14.0, *) {
                _ = try await store.requestFullAccessToEvents()
            } else {
                _ = try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                } as Bool
            }

            Self.hasRequestedAccess = true
            return true
        } catch {
            return false
        }
    }

    private func endDate(from now: Date, timeRange: String) -> Date {
        let calendar = Calendar.current
        switch timeRange.lowercased() {
        case "today":
            return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now.addingTimeInterval(86_400)
        case "24h":
            return now.addingTimeInterval(86_400)
        case "week":
            return now.addingTimeInterval(7 * 86_400)
        default:
            return now.addingTimeInterval(86_400)
        }
    }
}
