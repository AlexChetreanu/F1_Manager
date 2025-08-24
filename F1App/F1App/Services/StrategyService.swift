import Foundation

struct StrategyResponse: Decodable {
    let messages: [String]?
}

final class StrategyService {
    let session: URLSession
    let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL = URL(string: APIConfig.baseURL)!) {
        self.session = session
        self.baseURL = baseURL
    }

    func fetchMessages(sessionKey: Int) async throws -> [String] {
        var endpoint: URL
        if baseURL.lastPathComponent == "api" {
            endpoint = baseURL.appendingPathComponent("strategy")
        } else {
            endpoint = baseURL.appendingPathComponent("api").appendingPathComponent("strategy")
        }

        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "all", value: "1")
        ]
        let url = comps.url!
        let (data, _) = try await session.data(from: url)
        let dec = JSONDecoder()
        let resp = try dec.decode(StrategyResponse.self, from: data)
        return resp.messages ?? []
    }
}

