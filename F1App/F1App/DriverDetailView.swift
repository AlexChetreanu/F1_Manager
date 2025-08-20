import SwiftUI
import Combine

struct DriverDetailView: View {
    let driver: DriverInfo
    let sessionKey: Int?
    @ObservedObject var raceViewModel: HistoricalRaceViewModel
    @StateObject private var viewModel: DriverDetailViewModel

    init(driver: DriverInfo, sessionKey: Int?, raceViewModel: HistoricalRaceViewModel) {
        self.driver = driver
        self.sessionKey = sessionKey
        self.raceViewModel = raceViewModel
        _viewModel = StateObject(wrappedValue: DriverDetailViewModel(driver: driver,
                                                                    sessionKey: sessionKey))
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
                Text("Gear: \(viewModel.gear)")
                Text("Acceleration: \(viewModel.acceleration)")
                Text("Brake: \(viewModel.brake)")
                Text("DRS: \(viewModel.drs)")
                Text("Number of laps: \(viewModel.numberOfLaps)")
                Text("Status: \(viewModel.status)")
                Text("DSQ: \(viewModel.dsq ? "Yes" : "No")")

            }
            .padding()
        }
        .navigationTitle(driver.initials)
        .onAppear { updateTelemetry() }
        .onReceive(raceViewModel.$stepIndex) { _ in
            updateTelemetry()
        }
    }

    private func updateTelemetry() {
        if let timestamp = raceViewModel.currentPosition[driver.driver_number]?.date {
            viewModel.fetchTelemetry(at: timestamp)
        }
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
    @Published var gear: String = "-"
    @Published var numberOfLaps: Int = 0
    @Published var dsq: Bool = false
    @Published var compound: String = "-"
    @Published var status: String = "-"

    private let driverNumber: Int
    private let sessionKey: Int?

    init(driver: DriverInfo, sessionKey: Int?) {
        self.driverNumber = driver.driver_number
        self.sessionKey = sessionKey
        if sessionKey != nil {
            fetchStatus()
        }
    }

    private struct TelemetryResponse: Decodable {
        let data: [TelemetryData]
    }

    private struct TelemetryData: Decodable {
        let rpm: Double?
        let speed: Double?
        let throttle: Double?
        let brake: Double?
        let drs_status: Int?
        let gap_to_leader: String?
        let lap_number: Int?
        let n_gear: Int?
    }
    private struct OvertakesResponse: Decodable {
        let data: [Overtake]
    }

    private struct Overtake: Decodable {
        let position: Int?
    }
    private struct SessionResultResponse: Decodable {
        let data: [SessionResult]
    }

    private struct SessionResult: Decodable {
        let status: String?
    }


    func fetchTelemetry(at timestamp: String) {
        guard let sessionKey = sessionKey else { return }

        // fetch live position from overtakes endpoint
        fetchPosition(at: timestamp)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let startDate = formatter.date(from: timestamp) else {
            print("Telemetry fetch error: invalid timestamp \(timestamp)")
            return
        }

        let endDate = startDate.addingTimeInterval(1)
        let endTimestamp = formatter.string(from: endDate)

        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/car_data")!
        comps.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "driver_number", value: String(driverNumber)),
            URLQueryItem(name: "date__gte", value: timestamp),
            URLQueryItem(name: "date__lt", value: endTimestamp),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = comps.url else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Telemetry fetch error: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Telemetry fetch error: invalid response")
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                print("Telemetry fetch failed: status code \(httpResponse.statusCode)")
                return
            }

            guard let data = data else {
                print("Telemetry fetch error: no data")
                return
            }

            do {
                let response = try JSONDecoder().decode(TelemetryResponse.self, from: data)
                guard let telem = response.data.first else {
                    print("Telemetry fetch: empty payload")
                    return
                }
                DispatchQueue.main.async {
                    if let rpm = telem.rpm { self.rpm = String(Int(rpm)) }
                    if let speed = telem.speed { self.speed = String(format: "%.1f", speed) }
                    if let gear = telem.n_gear { self.gear = String(gear) }
                    if let throttle = telem.throttle { self.acceleration = String(format: "%.1f", throttle) }
                    if let brake = telem.brake { self.brake = String(format: "%.1f", brake) }
                    if let drs = telem.drs_status { self.drs = drs == 1 ? "On" : "Off" }
                    if let gap = telem.gap_to_leader { self.gapToLeader = gap }
                    if let lap = telem.lap_number { self.numberOfLaps = lap }
                }
            } catch {
                print("Telemetry decode error: \(error.localizedDescription)")
            }
        }.resume()
    }

    private func fetchPosition(at timestamp: String) {
        guard let sessionKey = sessionKey else { return }

        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/overtakes")!
        comps.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "driver_number", value: String(driverNumber)),
            URLQueryItem(name: "date__lte", value: timestamp),
            URLQueryItem(name: "order_by", value: "-date"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = comps.url else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Position fetch error: \(error.localizedDescription)")
                return
            }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                print("Position fetch failed: status code \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }
            guard let data = data else {
                print("Position fetch error: no data")
                return
            }
            do {
                let resp = try JSONDecoder().decode(OvertakesResponse.self, from: data)
                if let pos = resp.data.first?.position {
                    DispatchQueue.main.async { self.position = String(pos) }
                }
            } catch {
                print("Position decode error: \(error.localizedDescription)")
            }
        }.resume()
    }

    func fetchStatus() {
        guard let sessionKey = sessionKey else { return }
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/session_result")!
        comps.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "driver_number", value: String(driverNumber)),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = comps.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(SessionResultResponse.self, from: data),
                  let statusText = response.data.first?.status else { return }
            DispatchQueue.main.async {
                let upper = statusText.uppercased()
                if upper.contains("DNF") {
                    self.status = "DNF"
                } else if upper.contains("DNS") {
                    self.status = "DNS"
                } else {
                    self.status = statusText
                }
            }
        }.resume()
    }
}
