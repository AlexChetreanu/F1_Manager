import Foundation

/// Service responsible for fetching F1 related news.
///
/// The server allows filtering by year and limiting the number of items.
/// By default the current calendar year is requested and the limit is set to
/// the number of days in that year to cover an entire season.
final class NewsService {
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let session: URLSession

    init(baseURL: String = APIConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = URL(string: baseURL)!
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
        self.session = session
    }

    /// Fetches F1 news from the backend.
    /// - Parameters:
    ///   - days: Number of days back to include.
    ///   - limit: Maximum number of items to request.
    func fetchF1News(days: Int = 30, limit: Int = 20) async throws -> [NewsItem] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/news/f1"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let (data, _) = try await session.data(from: comps.url!)
        return try decoder.decode([NewsItem].self, from: data)
    }
}
