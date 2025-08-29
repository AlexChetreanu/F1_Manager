import Foundation

struct OpenF1Session: Decodable {
    let session_key: Int
}

struct LiveSnapshot: Decodable {
    struct DriverState: Decodable {
        struct Position: Decodable {
            let position: Int?
        }
        struct Location: Decodable {
            let x: Double?
            let y: Double?
        }

        let driver_number: Int
        let name_acronym: String?
        let team_name: String?
        let team_colour: String?
        let position: Position?
        let location: Location?

        var name: String {
            name_acronym ?? "Driver \(driver_number)"
        }
    }

    let session_key: Int?
    let ts: String?
    let drivers: [DriverState]
}

class HistoricalSnapshotService {
    func fetchSnapshot(year: Int, circuitKey: Int, completion: @escaping (Result<LiveSnapshot, Error>) -> Void) {
        var comps = URLComponents(string: "\(API.base)/api/openf1/sessions")
        comps?.queryItems = [
            URLQueryItem(name: "circuit_key", value: String(circuitKey)),
            URLQueryItem(name: "session_name", value: "Race"),
            URLQueryItem(name: "year", value: String(year))
        ]
        guard let sessionsURL = comps?.url else {
            completion(.failure(URLError(.badURL)))
            return
        }
        URLSession.shared.dataTask(with: sessionsURL) { data, resp, err in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let data = data,
                  let session = try? JSONDecoder().decode([OpenF1Session].self, from: data).first else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            let sessionKey = session.session_key
            var snapComps = URLComponents(string: "\(API.base)/api/live/snapshot")
            snapComps?.queryItems = [URLQueryItem(name: "session_key", value: String(sessionKey))]
            guard let snapshotURL = snapComps?.url else {
                completion(.failure(URLError(.badURL)))
                return
            }
            URLSession.shared.dataTask(with: snapshotURL) { data, resp, err in
                if let err = err {
                    completion(.failure(err))
                    return
                }
                guard let data = data else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                do {
                    let snapshot = try JSONDecoder().decode(LiveSnapshot.self, from: data)
                    completion(.success(snapshot))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        }.resume()
    }
}

