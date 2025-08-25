import Foundation

#if targetEnvironment(simulator)
let baseURL = URL(string: "http://127.0.0.1:8000")!
#else
let baseURL = URL(string: "http://<IP_LAN_MAC>:8000")! // ex. 192.168.1.23
#endif

enum API {
    static func url(_ path: String, query: [String:String]? = nil) -> URL {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
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
    guard let http = resp as? HTTPURLResponse else {
        print("\u{1F6AB} Non-HTTP response for", url.absoluteString)
        throw URLError(.badServerResponse)
    }
    guard (200..<300).contains(http.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
        print("\u{274C} HTTP", http.statusCode, "for", url.absoluteString, "-", body)
        throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(T.self, from: data)
}
