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
    @Published var weather: SnapshotResponse.Weather?
    @Published var raceControl: [SnapshotResponse.RaceControl] = []

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
    private var snapshotSince: String?

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

    private func fetchMeeting(year: Int, circuitKey: Int) {
        var comps = URLComponents(string: "http://127.0.0.1:8000/api/openf1/meetings")!
        comps.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "circuit_key", value: String(circuitKey))
        ]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let meetings = try? JSONDecoder().decode([Meeting].self, from: data),
                  let meeting = meetings.first else {
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
        var comps = URLComponents(string: "http://127.0.0.1:8000/api/live/resolve")!
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
                self.fetchSnapshot()
            }
        }.resume()
    }

    struct SnapshotResponse: Decodable {
        struct Session: Decodable {
            let session_key: Int
            let meeting_key: Int
            let status: String?
            let server_time: String?
        }
        struct DriverEntry: Decodable {
            struct Identity: Decodable {
                let full_name: String
                let team_name: String?
                let team_colour: String?
            }
            struct Position: Decodable {
                let position: Int?
                let gap_to_leader: String?
                let interval: String?
                let date: String?
            }
            struct Lap: Decodable {
                let lap_number: Int?
                let lap_duration: String?
                let date_start: String?
            }
            struct Car: Decodable {
                let speed: Double?
                let rpm: Double?
                let throttle: Double?
                let brake: Double?
                let n_gear: Int?
                let drs: Int?
                let date: String?
            }
            struct Loc: Decodable {
                let x: Double
                let y: Double
                let z: Double?
                let date: String
            }
            let identity: Identity?
            let position: Position?
            let lap: Lap?
            let car: Car?
            let loc: Loc?
        }
        struct Weather: Decodable {
            let air_temperature: Double?
            let track_temperature: Double?
            let humidity: Double?
            let pressure: Double?
            let wind_speed: Double?
            let wind_direction: Double?
            let rainfall: Double?
            let date: String?
        }
        struct RaceControl: Decodable {
            let flag: String?
            let message: String?
            let driver_number: Int?
            let date: String?
        }
        let session: Session
        let drivers: [String: DriverEntry]?
        let weather: Weather?
        let rc: [RaceControl]?
        let since: String?
    }

    private func fetchSnapshot() {
        guard let sessionKey = sessionKey else { return }
        var comps = URLComponents(string: "http://localhost:8000/api/live/snapshot")!
        comps.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "fields", value: "drivers,position,lap,car,loc,weather,rc"),
            URLQueryItem(name: "window_ms", value: "2000")
        ]
        if let since = snapshotSince {
            comps.queryItems?.append(URLQueryItem(name: "since", value: since))
        }
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let snap = try? JSONDecoder().decode(SnapshotResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self.snapshotSince = snap.since
                if let map = snap.drivers {
                    for (key, value) in map {
                        let dn = Int(key) ?? 0
                        if let identity = value.identity,
                           !self.drivers.contains(where: { $0.driver_number == dn }) {
                            let info = DriverInfo(driver_number: dn,
                                                   full_name: identity.full_name,
                                                   team_color: identity.team_colour,
                                                   team_name: identity.team_name)
                            self.drivers.append(info)
                        }
                        if let loc = value.loc {
                            let point = LocationPoint(driver_number: dn, date: loc.date, x: loc.x, y: loc.y)
                            var arr = self.positions[dn] ?? []
                            arr.append(point)
                            self.positions[dn] = arr
                            self.currentPosition[dn] = point
                        }
                    }
                    self.calculateLocationBounds()
                    self.updatePositions()
                }
                if let weather = snap.weather {
                    self.weather = weather
                }
                if let rc = snap.rc {
                    self.raceControl.append(contentsOf: rc)
                }
            }
        }.resume()
    }

    private func calculateLocationBounds() {
        guard let sample = positions.values.first, !sample.isEmpty else { return }
        let xs = sample.map { $0.x }
        let ys = sample.map { $0.y }
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

    private func year(from iso: String) -> Int {
        return Int(iso.prefix(4)) ?? 0
    }
}

