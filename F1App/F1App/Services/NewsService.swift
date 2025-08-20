import Foundation

final class NewsService {
    let session: URLSession
    let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL = URL(string: APIConfig.baseURL)!) {
        self.session = session
        self.baseURL = baseURL
    }

    func fetchF1News(days: Int = 30, limit: Int = 20) async throws -> [NewsItem] {
        var endpoint: URL
        if baseURL.lastPathComponent == "api" {
            endpoint = baseURL.appendingPathComponent("news").appendingPathComponent("f1")
        } else {
            endpoint = baseURL.appendingPathComponent("api").appendingPathComponent("news").appendingPathComponent("f1")
        }

        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let url = comps.url!
        print("FETCH URL:", url.absoluteString) // TODO: remove verbose logs before release

        let (data, _) = try await session.data(from: url)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        let items = try dec.decode([NewsItem].self, from: data)
        print("DECODED ITEMS:", items.count) // TODO: remove verbose logs before release
        return items
    }
}
