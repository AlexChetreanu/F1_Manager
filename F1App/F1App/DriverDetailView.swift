import SwiftUI

struct DriverDetailView: View {
    let driver: DriverInfo
    let sessionKey: Int?
    @StateObject private var viewModel: DriverDetailViewModel

    init(driver: DriverInfo, sessionKey: Int?) {
        self.driver = driver
        self.sessionKey = sessionKey
        _viewModel = StateObject(wrappedValue: DriverDetailViewModel(driver: driver, sessionKey: sessionKey))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(driver.full_name)
                    .font(.title)
                if let team = driver.team_name {
                    Text("Team: \(team)")
                }
                Text("Gap to leader: \(viewModel.gapToLeader)")
                Text("Position: \(viewModel.position)")
                Text("RPM: \(viewModel.rpm)")
                Text("Speed: \(viewModel.speed)")
                Text("Acceleration: \(viewModel.acceleration)")
                Text("Brake: \(viewModel.brake)")
                Text("DRS: \(viewModel.drs)")
                Text("Number of laps: \(viewModel.numberOfLaps)")
                Text("DSQ: \(viewModel.dsq ? "Yes" : "No")")

            }
            .padding()
        }
        .navigationTitle(driver.initials)
    }
}

class DriverDetailViewModel: ObservableObject {
    @Published var gapToLeader: String = "-"
    @Published var position: String = "-"
    @Published var rpm: String = "-"
    @Published var speed: String = "-"
    @Published var acceleration: String = "-"
    @Published var brake: String = "-"
    @Published var drs: String = "-"
    @Published var numberOfLaps: Int = 0
    @Published var dsq: Bool = false
    @Published var compound: String = "-"

    private let driverNumber: Int
    private let sessionKey: Int?

    init(driver: DriverInfo, sessionKey: Int?) {
        self.driverNumber = driver.driver_number
        self.sessionKey = sessionKey
        fetchSnapshot()
    }

    private struct SnapshotResponse: Decodable {
        struct DriverEntry: Decodable {
            struct Position: Decodable {
                let gap_to_leader: String?
                let position: Int?
            }
            struct Lap: Decodable {
                let lap_number: Int?
            }
            struct Car: Decodable {
                let rpm: Double?
                let speed: Double?
                let brake: Double?
                let throttle: Double?
                let drs: Int?

                enum CodingKeys: String, CodingKey {
                    case rpm, speed, brake, throttle
                    case drs = "drs_status"
                }
            }
            let position: Position?
            let lap: Lap?
            let car: Car?
        }
        struct RaceControl: Decodable {
            let flag: String?
            let driver_number: Int?
        }
        let drivers: [String: DriverEntry]?
        let rc: [RaceControl]?
    }

    private func fetchSnapshot() {
        guard let sessionKey = sessionKey else { return }
        var components = URLComponents(string: "\(APIConfig.baseURL)/api/live/snapshot")!
        components.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "fields", value: "position,lap,car,rc"),
            URLQueryItem(name: "window_ms", value: "2000")
        ]
        guard let url = components.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let snap = try? JSONDecoder().decode(SnapshotResponse.self, from: data),
                  let driverEntry = snap.drivers?[String(self.driverNumber)] else { return }
            DispatchQueue.main.async {
                if let pos = driverEntry.position {
                    self.gapToLeader = pos.gap_to_leader ?? "-"
                    if let p = pos.position { self.position = String(p) }
                }
                if let car = driverEntry.car {
                    if let rpm = car.rpm { self.rpm = String(Int(rpm)) }
                    if let speed = car.speed { self.speed = String(format: "%.1f", speed) }
                    if let throttle = car.throttle { self.acceleration = String(format: "%.1f", throttle) }
                    if let brake = car.brake { self.brake = String(format: "%.1f", brake) }
                    if let drs = car.drs { self.drs = drs == 1 ? "On" : "Off" }
                }
                if let lap = driverEntry.lap {
                    self.numberOfLaps = lap.lap_number ?? 0
                }
                if let rc = snap.rc {
                    self.dsq = rc.contains { ($0.flag ?? "").uppercased() == "DSQ" && $0.driver_number == self.driverNumber }
                }
            }
        }.resume()
    }
}
