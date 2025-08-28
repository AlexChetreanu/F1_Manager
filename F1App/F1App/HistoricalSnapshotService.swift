import Foundation

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
    func fetchSnapshot(year: Int, completion: @escaping (Result<LiveSnapshot, Error>) -> Void) {
        guard let sessionsURL = URL(string: "\(API.base)/api/openf1/sessions?year=\(year)&session_type=Race&limit=1") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        URLSession.shared.dataTask(with: sessionsURL) { data, resp, err in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let data = data,
                  let session = try? JSONDecoder().decode(Envelope<[SessionDTO]>.self, from: data).data.last else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            let sessionKey = session.session_key
            guard let snapshotURL = URL(string: "\(API.base)/api/live/snapshot?session_key=\(sessionKey)") else {
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

