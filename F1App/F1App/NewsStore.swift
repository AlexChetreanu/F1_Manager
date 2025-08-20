import Foundation
import Combine

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    private var lastLoaded: Date?
    private let ttl: TimeInterval = 300 // 5 min
    private let service: NewsService

    init(service: NewsService = .init()) { self.service = service }

    func loadIfNeeded() async {
        if let t = lastLoaded, Date().timeIntervalSince(t) < ttl, !items.isEmpty {
            return // cache valid -> nu refacem fetch
        }
        await refresh()
    }

    func refresh() async {
        do {
            let data = try await service.fetchF1News(days: 30, limit: 20)
            self.items = data
            self.lastLoaded = Date()
        } catch {
            print("News refresh error:", error)
        }
    }
}

