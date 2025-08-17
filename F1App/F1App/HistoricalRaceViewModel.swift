import Foundation
import SwiftUI
import CoreLocation

struct DriverInfo: Identifiable, Decodable, Hashable {
    let driver_number: Int
    let full_name: String
    let team_color: String?
    let team_name: String?

    var id: Int { driver_number }
    var initials: String {
        let parts = full_name.split(separator: " ")
        return parts.compactMap { $0.first }.map { String($0) }.joined()
    }

    private enum CodingKeys: String, CodingKey {
        case driver_number
        case full_name
        case team_color = "team_colour"
        case team_name
    }
}

struct LocationPoint: Decodable {
    let driver_number: Int
    let date: String
    let x: Double
    let y: Double
}

class HistoricalRaceViewModel: ObservableObject {
    @Published var year: String = ""
    @Published var errorMessage: String?
    @Published var drivers: [DriverInfo] = []
    @Published var positions: [Int: [LocationPoint]] = [:]
    @Published var currentPosition: [Int: LocationPoint] = [:]
    @Published var isRunning = false
    @Published var trackPoints: [CGPoint] = []
    @Published var sessionKey: Int?
    @Published var sessionStart: String?
    @Published var sessionEnd: String?
    @Published var stepIndex: Int = 0
    @Published var playbackSpeed: Double = 1.0
    @Published var currentStepDuration: Double = 1.0
    private var timer: Timer?
    private let speedOptions: [Double] = [1, 2, 5]
    private var speedIndex = 0
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private var trackBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var locationBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var locationFetchCount = 0

    func load(for race: Race) {
        pause()
        stepIndex = 0
        positions.removeAll()
        currentPosition.removeAll()
        parseTrack(race.coordinates)
        guard let yearInt = Int(year) else {
            errorMessage = "Selectează un an valid"
            return
        }
        guard let circuitId = race.circuit_id, let circuitKey = Int(circuitId) else {
            errorMessage = "Lipsește circuit_id"
            return
        }
        fetchMeeting(year: yearInt, circuitKey: circuitKey)
    }

    private struct Meeting: Decodable {
        let meeting_key: Int
    }

    private struct MeetingsResponse: Decodable {
        let data: [Meeting]
    }

    private func fetchMeeting(year: Int, circuitKey: Int) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/meetings")!
        comps.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "circuit_key", value: String(circuitKey))
        ]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                DispatchQueue.main.async { self.errorMessage = "Nu am găsit cursa" }
                return
            }
            let response = try? JSONDecoder().decode(MeetingsResponse.self, from: data)
            guard let meeting = response?.data.first else {
                DispatchQueue.main.async { self.errorMessage = "Nu am găsit cursa" }
                return
            }
            DispatchQueue.main.async {
                self.errorMessage = nil
                self.resolveSession(meetingKey: meeting.meeting_key, year: year)
            }
        }.resume()
    }

    private func parseTrack(_ json: String?) {
        guard
            let json = json,
            let data = json.data(using: .utf8),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]]
        else { return }

        let xs = arr.map { $0[0] }
        let ys = arr.map { $0[1] }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 1
        trackBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        trackPoints = arr.map { point in
            let x = (point[0] - trackBounds.minX) / trackBounds.width
            let y = 1 - (point[1] - trackBounds.minY) / trackBounds.height
            return CGPoint(x: x, y: y)
        }
    }

    private struct ResolveResponse: Decodable {
        let session_key: Int
        let date_start: String?
        let date_end: String?
    }

    private func resolveSession(meetingKey: Int, year: Int) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/live/resolve")!
        comps.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "meeting_key", value: String(meetingKey)),
            URLQueryItem(name: "session_type", value: "Race")
        ]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let session = try? JSONDecoder().decode(ResolveResponse.self, from: data) else {
                DispatchQueue.main.async { self.errorMessage = "Nu am găsit sesiunea" }
                return
            }
            DispatchQueue.main.async {
                self.sessionKey = session.session_key
                self.sessionStart = session.date_start
                self.sessionEnd = session.date_end
                self.errorMessage = nil
                self.fetchDrivers(meetingKey: meetingKey, sessionKey: session.session_key)
            }
        }.resume()
    }

    private struct DriversResponse: Decodable {
        let data: [DriverInfo]
    }

    private struct LocationsResponse: Decodable {
        let data: [LocationPoint]
    }

    private func fetchDrivers(meetingKey: Int, sessionKey: Int) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/drivers")!
        comps.queryItems = [URLQueryItem(name: "meeting_key", value: String(meetingKey))]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(DriversResponse.self, from: data) else { return }
            let uniqueDrivers = Array(Set(response.data))
            DispatchQueue.main.async {
                self.drivers = uniqueDrivers
                self.fetchLocations(sessionKey: sessionKey)
            }
        }.resume()
    }

    private func fetchLocations(sessionKey: Int) {
        let formatter = ISO8601DateFormatter()
        guard let startString = sessionStart,
              let start = formatter.date(from: startString) else { return }
        let end: Date
        if let endString = sessionEnd, let endDate = formatter.date(from: endString) {
            end = endDate
        } else {
            end = start.addingTimeInterval(3 * 60 * 60)
        }
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        locationFetchCount = 0
        for driver in drivers {
            var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/location")!
            comps.queryItems = [
                URLQueryItem(name: "session_key", value: String(sessionKey)),
                URLQueryItem(name: "driver_number", value: String(driver.driver_number)),
                URLQueryItem(name: "date__gte", value: startStr),
                URLQueryItem(name: "date__lte", value: endStr),
                URLQueryItem(name: "order_by", value: "date")
            ]
            guard let url = comps.url else { continue }
            URLSession.shared.dataTask(with: url) { data, _, error in
                defer {
                    DispatchQueue.main.async {
                        self.locationFetchCount += 1
                        if self.locationFetchCount == self.drivers.count {
                            self.errorMessage = self.positions.isEmpty ? "Date de locație indisponibile" : nil
                            if !self.positions.isEmpty {
                                self.calculateLocationBounds()
                                self.updatePositions()
                            }
                        }
                    }
                }
                guard error == nil, let data = data else { return }
                guard let response = try? JSONDecoder().decode(LocationsResponse.self, from: data),
                      !response.data.isEmpty else { return }
                DispatchQueue.main.async {
                    self.positions[driver.driver_number] = response.data
                    self.currentPosition[driver.driver_number] = response.data.first
                }
            }.resume()
        }
    }

    private func calculateLocationBounds() {
        let allPoints = positions.values.flatMap { $0 }
        guard !allPoints.isEmpty else { return }
        let xs = allPoints.map { $0.x }
        let ys = allPoints.map { $0.y }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 1
        locationBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public func point(for loc: LocationPoint, in size: CGSize) -> CGPoint {
        guard locationBounds.width != 0, locationBounds.height != 0 else { return .zero }
        let rawX = (loc.x - locationBounds.minX) / locationBounds.width
        let rawY = 1 - (loc.y - locationBounds.minY) / locationBounds.height
        let nx = max(0, min(rawX, 1))
        let ny = max(0, min(rawY, 1))
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }

    func start() {
        guard !isRunning else { pause(); return }
        guard maxSteps > 0 else { return }
        isRunning = true
        scheduleNextStep()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func cycleSpeed() {
        speedIndex = (speedIndex + 1) % speedOptions.count
        playbackSpeed = speedOptions[speedIndex]
        if isRunning {
            timer?.invalidate()
            scheduleNextStep()
        }
    }

    var maxSteps: Int {
        positions.values.map { $0.count }.max() ?? 0
    }

    func updatePositions() {
        for driver in drivers {
            if let arr = positions[driver.driver_number], stepIndex < arr.count {
                currentPosition[driver.driver_number] = arr[stepIndex]
            }
        }
    }

    private func scheduleNextStep() {
        guard isRunning, stepIndex < maxSteps - 1,
              let interval = timeIntervalForStep(stepIndex) else {
            pause()
            return
        }
        let scaled = interval / playbackSpeed
        currentStepDuration = scaled
        timer = Timer.scheduledTimer(withTimeInterval: scaled, repeats: false) { _ in
            withAnimation(.linear(duration: self.currentStepDuration)) {
                self.stepIndex += 1
                self.updatePositions()
            }
            self.scheduleNextStep()
        }
    }

    private func timeIntervalForStep(_ index: Int) -> TimeInterval? {
        for arr in positions.values {
            if index + 1 < arr.count,
               let start = dateFormatter.date(from: arr[index].date),
               let end = dateFormatter.date(from: arr[index + 1].date) {
                let diff = end.timeIntervalSince(start)
                if diff > 0 { return diff }
            }
        }
        return nil
    }

}

