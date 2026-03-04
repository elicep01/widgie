import Foundation

actor UserDataStore {
    static let shared = UserDataStore()

    private struct Payload: Codable {
        var checklistStates: [String: [String: Bool]] = [:]
        var checklistResetDay: [String: String] = [:]
        var habitCounts: [String: Int] = [:]
        var habitTargets: [String: Int] = [:]
        var habitStreaks: [String: Int] = [:]
        var habitLastLogDay: [String: String] = [:]
        var notes: [String: String] = [:]
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private var payload: Payload

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let root = Self.resolveRootDirectory(fileManager: fileManager)
        let userDataDirectory = root.appendingPathComponent("user_data", isDirectory: true)
        fileURL = userDataDirectory.appendingPathComponent("phase6_user_data.json")

        try? fileManager.createDirectory(at: userDataDirectory, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            payload = decoded
        } else {
            payload = Payload()
        }
    }

    func checklistState(for key: String, resetsDaily: Bool) -> [String: Bool] {
        if resetsDaily {
            let today = dayStamp()
            if payload.checklistResetDay[key] != today {
                payload.checklistStates[key] = [:]
                payload.checklistResetDay[key] = today
                persist()
            }
        }
        return payload.checklistStates[key] ?? [:]
    }

    func setChecklistItem(for key: String, itemID: String, checked: Bool, resetsDaily: Bool) {
        if resetsDaily {
            payload.checklistResetDay[key] = dayStamp()
        }

        var state = payload.checklistStates[key] ?? [:]
        state[itemID] = checked
        payload.checklistStates[key] = state
        persist()
    }

    func checklistProgress(for key: String) -> Double? {
        guard let values = payload.checklistStates[key]?.values,
              !values.isEmpty else {
            return nil
        }
        let checked = values.filter { $0 }.count
        return Double(checked) / Double(values.count)
    }

    func registerHabitTargets(_ habits: [HabitConfig], componentKey: String) {
        for habit in habits {
            let scopedKey = habitScopedKey(componentKey, habit.id)
            payload.habitTargets[scopedKey] = max(1, habit.target)

            let globalKey = habit.id.lowercased()
            if payload.habitTargets[globalKey] == nil {
                payload.habitTargets[globalKey] = max(1, habit.target)
            }
        }
        persist()
    }

    func habitCount(componentKey: String, habitID: String) -> Int {
        payload.habitCounts[habitScopedKey(componentKey, habitID)] ?? 0
    }

    func habitStreak(componentKey: String, habitID: String) -> Int {
        payload.habitStreaks[habitScopedKey(componentKey, habitID)] ?? 0
    }

    func incrementHabit(componentKey: String, habitID: String) {
        let key = habitScopedKey(componentKey, habitID)
        let globalKey = habitID.lowercased()
        payload.habitCounts[key, default: 0] += 1
        payload.habitCounts[globalKey, default: 0] += 1

        let today = dayStamp()
        let yesterday = dayStamp(for: Date().addingTimeInterval(-86_400))
        let previousDay = payload.habitLastLogDay[key]

        if previousDay == today {
            // Keep current streak.
        } else if previousDay == yesterday {
            payload.habitStreaks[key, default: 0] += 1
        } else {
            payload.habitStreaks[key] = 1
        }

        payload.habitLastLogDay[key] = today
        payload.habitLastLogDay[globalKey] = today
        persist()
    }

    func habitProgress(for habitID: String, componentKey: String?) -> Double? {
        let scoped = componentKey.map { habitScopedKey($0, habitID) }
        let global = habitID.lowercased()

        let candidateKeys = [scoped, global].compactMap { $0 }
        for key in candidateKeys {
            if let target = payload.habitTargets[key], target > 0 {
                let count = payload.habitCounts[key, default: 0]
                return min(1, max(0, Double(count) / Double(target)))
            }
        }
        return nil
    }

    func note(for key: String) -> String? {
        payload.notes[key]
    }

    func setNote(_ value: String, for key: String) {
        payload.notes[key] = value
        persist()
    }

    private func habitScopedKey(_ componentKey: String, _ habitID: String) -> String {
        "\(componentKey)#\(habitID.lowercased())"
    }

    private func dayStamp(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func resolveRootDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let currentRoot = appSupport.appendingPathComponent("widgie", isDirectory: true)
        let legacyPaneRoot = appSupport.appendingPathComponent("pane", isDirectory: true)
        let legacyWidgetForgeRoot = appSupport.appendingPathComponent("WidgetForge", isDirectory: true)

        if fileManager.fileExists(atPath: currentRoot.path) {
            return currentRoot
        }

        if fileManager.fileExists(atPath: legacyPaneRoot.path) {
            do {
                try fileManager.moveItem(at: legacyPaneRoot, to: currentRoot)
                return currentRoot
            } catch {
                return legacyPaneRoot
            }
        }

        if fileManager.fileExists(atPath: legacyWidgetForgeRoot.path) {
            do {
                try fileManager.moveItem(at: legacyWidgetForgeRoot, to: currentRoot)
                return currentRoot
            } catch {
                return legacyWidgetForgeRoot
            }
        }

        return currentRoot
    }
}
