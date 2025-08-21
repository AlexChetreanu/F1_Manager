import Foundation

struct DriverLocation: Decodable {
    let driverNumber: Int
    let dateIso: String
    let x: Int
    let y: Int
    let z: Int?

    private enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case dateIso = "date"
        case x, y, z
    }
}

final class TrackPositionService {
    static let shared = TrackPositionService()
    private init() {}

    /// Fetch "chunk" of positions for a driver, in a window [gt, lt] ISO8601, ordered by date.
    func fetchLocations(sessionKey: Int,
                        driverNumber: Int,
                        dateGtISO: String,
                        dateLtISO: String,
                        limit: Int = 1000,
                        offset: Int = 0,
                        completion: @escaping (Result<[DriverLocation], Error>) -> Void) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/location")!
        comps.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "driver_number", value: String(driverNumber)),
            URLQueryItem(name: "date__gt", value: dateGtISO),
            URLQueryItem(name: "date__lt", value: dateLtISO),
            URLQueryItem(name: "order_by", value: "date"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        guard let url = comps.url else {
            completion(.success([]))
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.success([]))
                return
            }
            do {
                struct Response: Decodable { let data: [DriverLocation] }
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                completion(.success(decoded.data))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Helper: transform ISO String -> Date (UTC + fractions).
    static func parseISO(_ s: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: s)
    }

    /// Helper: Date -> ISO String (UTC + fractions).
    static func isoString(_ d: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: d)
    }
}

