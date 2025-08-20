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
    ///   - year: Calendar year to retrieve news for. Defaults to the current year.
    ///   - limit: Maximum number of items to request. Defaults to the number of days in the given year.
    func fetchF1News(year: Int = Calendar.current.component(.year, from: Date()),
                     limit: Int? = nil) async throws -> [NewsItem] {
        let computedLimit: Int = {
            if let limit { return limit }
            let calendar = Calendar.current
            let start = calendar.date(from: DateComponents(year: year))!
            return calendar.range(of: .day, in: .year, for: start)!.count
        }()

        var comps = URLComponents(url: baseURL.appendingPathComponent("api/news/f1"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "limit", value: String(computedLimit))
        ]
        let (data, _) = try await session.data(from: comps.url!)
        return try decoder.decode([NewsItem].self, from: data)
    }
}
