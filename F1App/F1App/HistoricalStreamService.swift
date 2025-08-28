import Foundation

/// Basic session info returned by /historical/resolve
struct SessionInfo: Codable {
    let session_key: Int
    let meeting_key: Int
    let date_start: String
    let date_end: String
    let circuit_key: Int
}

/// Manifest describing available resources for a session.
struct Manifest: Codable {
    struct TimeInfo: Codable { let start: String; let end: String; let duration_ms: Int; let sample_rate_hz: Int }
    struct Resources: Codable {
        let drivers: String
        let track: String
        let events: String
        let laps: String
        let frames: FrameEndpoints
    }
    struct FrameEndpoints: Codable { let by_time: String; let window: String }
    let session_key: Int
    let time: TimeInfo
    let resources: Resources
}

/// Driver information mapped from OpenF1
struct DriverDTO: Codable {
    let driver_number: String
    let full_name: String
    let team_name: String?
    let team_colour: String?
    let headshot_url: String?
}

/// Frame representation used by playback.
struct FrameDTO: Decodable {
    let t: Date
    let drivers: [[FieldValue]]
    let fields: [String]

    struct FieldValue: Decodable {
        let string: String?
        let double: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let d = try? container.decode(Double.self) {
                self.double = d
                self.string = nil
            } else if let s = try? container.decode(String.self) {
                self.string = s
                self.double = Double(s)
            } else {
                self.string = nil
                self.double = nil
            }
        }
    }
}

/// Service responsible for talking to the backend historical API.
final class HistoricalStreamService {
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(baseURL: String = API.historicalBase) {
        self.baseURL = URL(string: baseURL)!
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    /// Resolve a session using year and circuit key.
    func resolve(year: Int, circuitKey: Int) async throws -> SessionInfo {
        var comps = URLComponents(url: baseURL.appendingPathComponent("historical/resolve"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "circuit_key", value: String(circuitKey))
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try decoder.decode(SessionInfo.self, from: data)
    }

    /// Download manifest for a session.
    func manifest(sessionKey: Int) async throws -> Manifest {
        let url = baseURL.appendingPathComponent("historical/session/\(sessionKey)/manifest")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(Manifest.self, from: data)
    }

    /// Fetch driver metadata.
    func fetchDrivers(sessionKey: Int) async throws -> [DriverDTO] {
        let url = baseURL.appendingPathComponent("historical/session/\(sessionKey)/drivers")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([DriverDTO].self, from: data)
    }

    /// Stream frames from the backend using NDJSON when possible.
    func streamFrames(sessionKey: Int,
                      from: Date,
                      to: Date,
                      strideMs: Int,
                      drivers: [Int]? = nil,
                      format: String = "ndjson",
                      delta: Bool = false) async throws -> AsyncThrowingStream<FrameDTO, Error> {
        var comps = URLComponents(url: baseURL.appendingPathComponent("historical/session/\(sessionKey)/frames"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "from", value: ISO8601DateFormatter().string(from: from)),
            URLQueryItem(name: "to", value: ISO8601DateFormatter().string(from: to)),
            URLQueryItem(name: "stride_ms", value: String(strideMs)),
            URLQueryItem(name: "format", value: format),
            URLQueryItem(name: "gap_ms", value: "1500"),
        ]
        if let drivers = drivers { items.append(URLQueryItem(name: "drivers", value: drivers.map(String.init).joined(separator: ","))) }
        if delta { items.append(URLQueryItem(name: "delta", value: "1")) }
        comps.queryItems = items
        let url = comps.url!
        var request = URLRequest(url: url)
        request.addValue("application/x-ndjson", forHTTPHeaderField: "Accept")

        if format == "ndjson" {
            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        for try await line in bytes.lines {
                            if line.isEmpty { continue }
                            if let data = line.data(using: .utf8) {
                                let frame = try decoder.decode(FrameDTO.self, from: data)
                                continuation.yield(frame)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } else {
            let (data, _) = try await URLSession.shared.data(for: request)
            let frames = try decoder.decode([FrameDTO].self, from: data)
            return AsyncThrowingStream { continuation in
                for frame in frames { continuation.yield(frame) }
                continuation.finish()
            }
        }
    }
}
