import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var items: [NewsItem] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var info: String?

    private let service = NewsService()

    func load() async {
        isLoading = true
        error = nil
        info = nil
        let limit = 20
        do {
            let fetched = try await service.fetchF1News(days: 30, limit: limit)
            print("News count:", fetched.count)
            items = fetched
            if fetched.count < limit {
                info = "Doar \(fetched.count) din \(limit) știri disponibile."
            }
        } catch {
            self.error = "Eroare la încărcarea știrilor"
        }
        isLoading = false
    }
}
