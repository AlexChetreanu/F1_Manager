import Foundation

final class RequestThrottler {
    static let shared = RequestThrottler(maxRequestsPerSecond: 3)

    private let queue = DispatchQueue(label: "RequestThrottler")
    private let interval: TimeInterval
    private var lastRequest: Date = .distantPast

    init(maxRequestsPerSecond: Int) {
        interval = 1.0 / Double(maxRequestsPerSecond)
    }

    func execute(_ block: @escaping () -> Void) {
        queue.async {
            let now = Date()
            let wait = self.lastRequest.addingTimeInterval(self.interval).timeIntervalSince(now)
            if wait > 0 {
                Thread.sleep(forTimeInterval: wait)
            }
            self.lastRequest = Date()
            block()
        }
    }
}

