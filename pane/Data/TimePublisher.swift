import Combine
import Foundation

@MainActor
final class TimePublisher: ObservableObject {
    static let shared = TimePublisher()

    @Published private(set) var now: Date

    private var cancellable: AnyCancellable?

    private init() {
        now = Date()
        cancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] value in
                self?.now = value
            }
    }
}
