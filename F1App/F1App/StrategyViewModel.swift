import Foundation

@MainActor
class StrategyViewModel: ObservableObject {
    @Published var messages: [String] = []
    private let service: StrategyService
    private var timer: Timer?

    init(service: StrategyService = StrategyService()) {
        self.service = service
    }

    func start(sessionKey: Int) {
        fetch(sessionKey: sessionKey)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetch(sessionKey: sessionKey)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func fetch(sessionKey: Int) {
        Task {
            do {
                let msgs = try await service.fetchMessages(sessionKey: sessionKey)
                self.messages = msgs
            } catch {
                print("Strategy fetch failed: \(error)")
            }
        }
    }
}

