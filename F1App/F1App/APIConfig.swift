import Foundation

enum APIConfig {
    /// Base URL for API requests, read from Info.plist.
    static let baseURL: String = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "http://172.20.10.10:8000"
        let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        assert(!url.contains("127.0.0.1") && !url.contains("localhost"),
               "Use host IP (e.g., http://172.20.10.10:8000) in Simulator.")
        return url
    }()
}

