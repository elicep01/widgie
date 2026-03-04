import EventKit
import Foundation

@MainActor
final class ReminderProvider {
    private let store = EKEventStore()
    private enum AccessState {
        case unknown
        case granted
        case denied
    }

    private static var accessState: AccessState = .unknown

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
            Self.accessState = .granted
            return true
        } catch {
            // In sandbox-restricted environments this can fail repeatedly; cache denial
            // so we avoid retry storms and noisy logs.
            Self.accessState = .denied
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
