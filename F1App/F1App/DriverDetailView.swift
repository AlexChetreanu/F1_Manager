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
                Text("Brake: \(viewModel.brake)")
                Text("Number of laps: \(viewModel.numberOfLaps)")
           //     Text("DSQ: \(viewModel.dsq ? \"Yes\" : \"No\")")
           //     Text("Compound: \(viewModel.compound)")
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
    @Published var brake: String = "-"
    @Published var numberOfLaps: Int = 0
    @Published var dsq: Bool = false
    @Published var compound: String = "-"

    private let driverNumber: Int
    private let sessionKey: Int?

    init(driver: DriverInfo, sessionKey: Int?) {
        self.driverNumber = driver.driver_number
        self.sessionKey = sessionKey
        fetchData()
    }

    func fetchData() {
        guard let sessionKey = sessionKey else { return }
        fetchPosition(sessionKey: sessionKey)
        fetchCarData(sessionKey: sessionKey)
        fetchLaps(sessionKey: sessionKey)
        fetchDSQ(sessionKey: sessionKey)
    }

    private struct PositionResponse: Decodable {
        let gap_to_leader: String?
        let position: Int?
    }

    private func fetchPosition(sessionKey: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/position?session_key=\(sessionKey)&driver_number=\(driverNumber)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let result = try? JSONDecoder().decode([PositionResponse].self, from: data),
                  let last = result.last else { return }
            DispatchQueue.main.async {
                self.gapToLeader = last.gap_to_leader ?? "-"
                if let pos = last.position {
                    self.position = String(pos)
                }
            }
        }.resume()
    }

    private struct CarDataResponse: Decodable {
        let rpm: Double?
        let speed: Double?
        let brake: Double?
    }

    private func fetchCarData(sessionKey: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/car_data?session_key=\(sessionKey)&driver_number=\(driverNumber)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let result = try? JSONDecoder().decode([CarDataResponse].self, from: data),
                  let last = result.last else { return }
            DispatchQueue.main.async {
                if let rpm = last.rpm { self.rpm = String(Int(rpm)) }
                if let speed = last.speed { self.speed = String(format: "%.1f", speed) }
                if let brake = last.brake { self.brake = String(format: "%.1f", brake) }
            }
        }.resume()
    }

    private struct LapResponse: Decodable {
        let lap_number: Int?
        let compound: String?
    }

    private func fetchLaps(sessionKey: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/laps?session_key=\(sessionKey)&driver_number=\(driverNumber)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let result = try? JSONDecoder().decode([LapResponse].self, from: data) else { return }
            DispatchQueue.main.async {
                self.numberOfLaps = result.count
                self.compound = result.last?.compound ?? "-"
            }
        }.resume()
    }

    private struct RaceControlResponse: Decodable {
        let flag: String?
    }

    private func fetchDSQ(sessionKey: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/race_control?session_key=\(sessionKey)&driver_number=\(driverNumber)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let result = try? JSONDecoder().decode([RaceControlResponse].self, from: data) else { return }
            DispatchQueue.main.async {
                self.dsq = result.contains { ($0.flag ?? "").uppercased() == "DSQ" }
            }
        }.resume()
    }
}
