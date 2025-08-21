import Foundation

class RaceEventService {
    private let session: URLSession
    private var cache: [ClosedRange<Int64>: [RaceEvent]] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchEvents(sessionKey: Int, fromMs: Int64, toMs: Int64, types: [RaceEvent.EventType]) async throws -> [RaceEvent] {
        let range = fromMs...toMs
        if let cached = cache[range] {
            return cached
        }

        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/races/\(sessionKey)/events")!
        comps.queryItems = [
            URLQueryItem(name: "from_ms", value: String(fromMs)),
            URLQueryItem(name: "to_ms", value: String(toMs)),
            URLQueryItem(name: "types", value: types.map { $0.rawValue }.joined(separator: ","))
        ]
        let (data, _) = try await session.data(from: comps.url!)
        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(ResponseWrapper.self, from: data)
        cache[range] = wrapper.events
        return wrapper.events
    }

    private struct ResponseWrapper: Decodable {
        let events: [RaceEvent]
    }
}
