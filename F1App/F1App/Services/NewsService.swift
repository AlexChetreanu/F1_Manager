import Foundation

final class NewsService {
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let session: URLSession

    init(baseURL: String = APIConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = URL(string: baseURL)!
        self.session = session
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    /// Fetch news articles for a given season.
    /// - Parameters:
    ///   - year: The F1 season to load, typically the current calendar year.
    ///   - limit: Maximum number of articles to return.
    func fetchF1News(year: Int, limit: Int = 365) async throws -> [NewsItem] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/news/f1"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let (data, _) = try await session.data(from: comps.url!)
        return try decoder.decode([NewsItem].self, from: data)
    }
}
