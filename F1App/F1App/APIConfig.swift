import Foundation

enum APIConfig {
    /// Base URL for API requests.
    /// Defaults to `http://127.0.0.1:8000` but can be overridden using
    /// `UserDefaults.standard.set("http://192.168.1.10:8000", forKey: "api_base_url")`.
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "api_base_url") ?? "http://127.0.0.1:8000"
    }
}

