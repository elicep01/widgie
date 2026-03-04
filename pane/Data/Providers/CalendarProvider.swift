import EventKit
import Foundation

@MainActor
final class CalendarProvider {
    private let store = EKEventStore()
    private enum AccessState {
        case unknown
        case granted
        case denied
    }

    private static var accessState: AccessState = .unknown

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
        switch Self.accessState {
        case .granted:
            return true
        case .denied:
            return false
        case .unknown:
            break
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

            Self.accessState = .granted
            return true
        } catch {
            // In sandbox-restricted environments this can fail repeatedly; cache denial
            // so we avoid spamming CalendarAgent retries on every refresh.
            Self.accessState = .denied
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
