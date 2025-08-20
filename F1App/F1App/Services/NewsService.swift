import Foundation

final class NewsService {
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(baseURL: String = APIConfig.baseURL) {
        self.baseURL = URL(string: baseURL)!
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func fetchF1News(days: Int = 30, limit: Int = 20) async throws -> [NewsItem] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/news/f1"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try decoder.decode([NewsItem].self, from: data)
    }
}
