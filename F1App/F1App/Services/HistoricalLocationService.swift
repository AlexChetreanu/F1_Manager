import Foundation

struct DriverLocationDTO: Decodable {
    let driverNumber: Int
    let date: String?
    let dateIso: String?
    let x: Int
    let y: Int
    let z: Int?

    private enum CodingKeys: String, CodingKey {
        case driverNumber = "driver_number"
        case date
        case dateIso = "date_iso"
        case x
        case y
        case z
    }
}

final class HistoricalLocationService {
    var logger: DebugLogger?

    func fetchChunk(sessionKey: Int,
                    driverNumber: Int,
                    dateGtISO: String,
                    dateLtISO: String,
                    limit: Int = 1000,
                    offset: Int = 0,
                    completion: @escaping (Result<[DriverLocationDTO], Error>) -> Void) {
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
        let url = comps.url!
        URLSession.shared.dataTask(with: url) { data, resp, error in
            self.logger?.log("GET /openf1/location", "url=\(url)\nerr=\(String(describing: error)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)")
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.success([]))
                return
            }
            do {
                struct Response: Decodable { let data: [DriverLocationDTO] }
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                completion(.success(decoded.data))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

