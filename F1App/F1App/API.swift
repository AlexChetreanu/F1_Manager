import Foundation

enum API {
    static let base: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
            ?? "http://MacBook-Pro-Alexandru.local:8000"
        let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                     .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("\u{1F517} API_BASE_URL =", url)
        assert(!url.contains("127.0.0.1") && !url.contains("localhost"),
               "Do not use localhost/127.0.0.1 in Simulator; use .local or the host IP.")
        return url
    }()

    static func url(_ path: String, query: [String:String]? = nil) -> URL {
        var comps = URLComponents(string: API.base)!
        comps.path = comps.path + (path.hasPrefix("/") ? path : "/" + path)
        if let query {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let u = comps.url!
        print("\u{1F310} FETCH:", u.absoluteString)
        return u
    }
}

func getJSON<T: Decodable>(_ path: String, query: [String:String]? = nil) async throws -> T {
    let url = API.url(path, query: query)
    let (data, resp) = try await URLSession.shared.data(from: url)
    guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(T.self, from: data)
}
