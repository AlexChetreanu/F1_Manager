import Foundation

enum API {
    static let base: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
            ?? "http://MacBook-Pro-Alexandru.local:8000" // stable fallback
        let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                     .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("\u{1F517} API_BASE_URL =", url)
        assert(!url.contains("172.20.10.10"),
               "Stale IP detected in API_BASE_URL — update Info.plist or use .local")
        return url
    }()
}
