import Foundation

@MainActor
final class AIRateLimiter {
    static let shared = AIRateLimiter()

    private struct State: Codable {
        let dayKey: String
        var count: Int
    }

    private let defaults: UserDefaults
    private let storageKey = "ai.rateLimiter.dailyPipelineState"
    private let limitPerDay = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func reservePipelineRun() throws {
        var state = loadState()
        let today = currentDayKey()

        if state.dayKey != today {
            state = State(dayKey: today, count: 0)
        }

        guard state.count < limitPerDay else {
            throw AIWidgetServiceError.requestFailed(
                "Daily limit reached. Resets at midnight."
            )
        }

        state.count += 1
        saveState(state)
    }

    func remainingPipelineRunsToday() -> Int {
        var state = loadState()
        let today = currentDayKey()

        if state.dayKey != today {
            state = State(dayKey: today, count: 0)
        }

        return max(0, limitPerDay - state.count)
    }

    private func loadState() -> State {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(State.self, from: data) else {
            return State(dayKey: currentDayKey(), count: 0)
        }

        return decoded
    }

    private func saveState(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    private func currentDayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
