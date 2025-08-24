import Foundation

final class NewsService {
    func fetchF1News(days: Int = 30, limit: Int = 20) async throws -> [NewsItem] {
        let url = API.url("/api/news/f1", query: [
            "days": String(days),
            "limit": String(limit)
        ])
        let (data, _) = try await URLSession.shared.data(from: url)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        return try dec.decode([NewsItem].self, from: data)
    }
}
