import EventKit
import Foundation

@MainActor
final class ReminderProvider {
    private let store = EKEventStore()
    private static var hasRequestedAccess = false

    func fetch(maxItems: Int, includeCompleted: Bool = false) async -> [ReminderSnapshot] {
        guard await requestAccessIfNeeded() else {
            return []
        }

        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        do {
            let reminders = try await fetchReminders(using: predicate)
            let filtered = includeCompleted ? reminders : reminders.filter { !$0.isCompleted }

            return filtered
                .sorted(by: { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) })
                .prefix(max(1, maxItems))
                .map {
                    ReminderSnapshot(
                        id: $0.calendarItemIdentifier,
                        title: $0.title,
                        dueDate: $0.dueDateComponents?.date,
                        isCompleted: $0.isCompleted
                    )
                }
        } catch {
            return []
        }
    }

    private func requestAccessIfNeeded() async -> Bool {
        if Self.hasRequestedAccess {
            return true
        }

        do {
            if #available(macOS 14.0, *) {
                _ = try await store.requestFullAccessToReminders()
            } else {
                _ = try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .reminder) { granted, error in
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

    private func fetchReminders(using predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
}
