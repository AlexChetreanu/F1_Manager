import Foundation

enum APIConfig {
    /// Base URL for API requests.
    /// Defaults depend on the build target but can be overridden using
    /// `UserDefaults.standard.set("http://192.168.1.10:8000", forKey: "api_base_url")`.
    private static let defaultBaseURL: String = {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8000"
        #else
        return "http://192.168.0.100:8000" // Replace with your Mac's LAN IP for physical device
        #endif
    }()

    static var baseURL: String {
        UserDefaults.standard.string(forKey: "api_base_url") ?? defaultBaseURL
    }
}

