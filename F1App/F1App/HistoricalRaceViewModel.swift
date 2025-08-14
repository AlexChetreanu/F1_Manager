import Foundation
import SwiftUI
import CoreLocation

struct Meeting: Decodable {
    let meeting_key: Int
    let date_start: String
}

struct DriverInfo: Identifiable, Decodable, Hashable {
    let driver_number: Int
    let full_name: String

    var id: Int { driver_number }
    var initials: String {
        let parts = full_name.split(separator: " ")
        return parts.compactMap { $0.first }.map { String($0) }.joined()
    }
}

struct LocationPoint: Decodable {
    let driver_number: Int
    let date: String
    let x: Double
    let y: Double
}

struct SessionInfo: Decodable {
    let session_key: Int
    let session_name: String
    let date_start: String?
    let date_end: String?
}

class HistoricalRaceViewModel: ObservableObject {
    @Published var year: String = ""
    @Published var errorMessage: String?
    @Published var meeting: Meeting?
    @Published var drivers: [DriverInfo] = []
    @Published var positions: [Int: [LocationPoint]] = [:]
    @Published var currentPosition: [Int: LocationPoint] = [:]
    @Published var isRunning = false
    @Published var trackPoints: [CGPoint] = []
    @Published var sessionKey: Int?
    @Published var sessionStart: String?
    @Published var sessionEnd: String?
    @Published var stepIndex: Int = 0

    private var timer: Timer?
    private var trackBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var locationBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var isFetchingLocations = false
    private var hasInitialLocations = false

    func load(for race: Race) {
        pause()
        stepIndex = 0
        positions.removeAll()
        currentPosition.removeAll()
        parseTrack(race.coordinates)
        guard let circuitId = race.circuit_id, let yearInt = Int(year) else {
            errorMessage = "Selectează un an valid"
            return
        }
        fetchMeeting(circuitId: circuitId, year: yearInt)
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

    private func fetchMeeting(circuitId: String, year: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/meetings?circuit_key=\(circuitId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let meetings = try? JSONDecoder().decode([Meeting].self, from: data),
                  let meeting = meetings.first(where: { self.year(from: $0.date_start) == year }) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Nu a fost cursa pe acel circuit in acel an"
                }
                return
            }
            DispatchQueue.main.async {
                self.meeting = meeting
                self.errorMessage = nil
                self.fetchSession(meetingKey: meeting.meeting_key)
            }
        }.resume()
    }

    private func fetchSession(meetingKey: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/sessions?meeting_key=\(meetingKey)&session_name=Race") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let sessions = try? JSONDecoder().decode([SessionInfo].self, from: data),
                  let session = sessions.first else {
                DispatchQueue.main.async {
                    self.errorMessage = "Nu am găsit sesiunea pentru cursă"
                }
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

    private func fetchDrivers(meetingKey: Int, sessionKey: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/drivers?meeting_key=\(meetingKey)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let drivers = try? JSONDecoder().decode([DriverInfo].self, from: data) else { return }
            let uniqueDrivers = Array(Set(drivers))
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

        positions.removeAll()
        currentPosition.removeAll()
        hasInitialLocations = false
        isFetchingLocations = true

        fetchLocationChunk(sessionKey: sessionKey, current: start, end: end, formatter: formatter)
    }

    private func fetchLocationChunk(sessionKey: Int, current: Date, end: Date, formatter: ISO8601DateFormatter) {
        let step: TimeInterval = 5 * 60
        let next = min(current.addingTimeInterval(step), end)

        let startStr = formatter.string(from: current)
        let endStr = formatter.string(from: next)
        let urlString = "https://api.openf1.org/v1/location?session_key=\(sessionKey)&date>=\(startStr)&date<=\(endStr)"
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else {
            if next < end {
                fetchLocationChunk(sessionKey: sessionKey, current: next, end: end, formatter: formatter)
            } else {
                isFetchingLocations = false
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, error == nil,
               let locs = try? JSONDecoder().decode([LocationPoint].self, from: data) {
                let grouped = Dictionary(grouping: locs, by: { $0.driver_number })

                DispatchQueue.main.async {
                    var exceededBounds = false
                    for driver in self.drivers {
                        if let arr = grouped[driver.driver_number], !arr.isEmpty {
                            var existing = self.positions[driver.driver_number] ?? []
                            existing.append(contentsOf: arr)
                            self.positions[driver.driver_number] = existing
                            if self.currentPosition[driver.driver_number] == nil {
                                self.currentPosition[driver.driver_number] = arr.first
                            }
                            if self.hasInitialLocations && !exceededBounds {
                                for loc in arr {
                                    let p = CGPoint(x: loc.x, y: loc.y)
                                    if !self.locationBounds.contains(p) {
                                        exceededBounds = true
                                        break
                                    }
                                }
                            }
                        }
                    }
                    self.errorMessage = self.positions.isEmpty ? "Date de locație indisponibile" : nil
                    let totalLocations = self.positions.values.reduce(0) { $0 + $1.count }
                    if !self.hasInitialLocations, totalLocations >= 2 {
                        self.calculateLocationBounds()
                        self.updatePositions()
                        self.hasInitialLocations = true
                    } else if self.hasInitialLocations {
                        if exceededBounds {
                            self.calculateLocationBounds()
                        }
                        self.updatePositions()
                    }
                }
            }
            if next < end {
                self.fetchLocationChunk(sessionKey: sessionKey, current: next, end: end, formatter: formatter)
            } else {
                DispatchQueue.main.async { self.isFetchingLocations = false }
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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.stepIndex < self.maxSteps - 1 {
                self.stepIndex += 1
                self.updatePositions()
            } else if !self.isFetchingLocations {
                self.pause()
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
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

    private func year(from iso: String) -> Int {
        return Int(iso.prefix(4)) ?? 0
    }
}
