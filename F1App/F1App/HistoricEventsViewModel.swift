import Foundation
import Combine

class HistoricEventsViewModel: ObservableObject {
    @Published var activeToasts: [ToastEvent] = []

    private var sessionKey: Int
    private let service: RaceEventService
    private var preloaded: [ClosedRange<Int64>: [RaceEvent]] = [:]
    private var shownEventIds: Set<Int64> = []

    init(sessionKey: Int, service: RaceEventService = RaceEventService()) {
        self.sessionKey = sessionKey
        self.service = service
    }

    func setSessionKey(_ newKey: Int) {
        sessionKey = newKey
        preloaded.removeAll()
        shownEventIds.removeAll()
        activeToasts.removeAll()
    }

    func update(nowMs: Int64) {
        Task {
            await preloadIfNeeded(nowMs: nowMs)
            await MainActor.run {
                self.removeExpired(nowMs: nowMs)
                self.addNewToasts(nowMs: nowMs)
            }
        }
    }

    private func preloadIfNeeded(nowMs: Int64) async {
        let windowStart = nowMs - 60_000
        let windowEnd = nowMs + 60_000
        let range = windowStart...windowEnd
        guard preloaded.keys.first(where: { $0.contains(nowMs) }) == nil else { return }
        do {
            let events = try await service.fetchEvents(sessionKey: sessionKey, fromMs: windowStart, toMs: windowEnd, types: [.overtake, .race_control])
            preloaded[range] = events
        } catch {
            // ignore errors for now
        }
    }

    private func events(in range: ClosedRange<Int64>) -> [RaceEvent] {
        for (window, evts) in preloaded where window.overlaps(range) {
            return evts.filter { range.contains($0.timestampMs) }
        }
        return []
    }

    private func removeExpired(nowMs: Int64) {
        activeToasts.removeAll { $0.expiresAtMs <= nowMs }
    }

    private func addNewToasts(nowMs: Int64) {
        let window = (nowMs-20_000)...nowMs
        let candidates = events(in: window).filter { e in
            nowMs >= e.timestampMs && nowMs < e.timestampMs + 20_000 && !shownEventIds.contains(e.id)
        }
        for event in candidates {
            if activeToasts.count >= 3 { break }
            shownEventIds.insert(event.id)
            activeToasts.append(ToastEvent(id: event.id, event: event, expiresAtMs: event.timestampMs + 20_000))
        }
    }
}
