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
    private var locationTransform: CGAffineTransform = .identity
    private var locationFetchCount = 0

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

        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        locationFetchCount = 0
        for driver in drivers {
            let urlString = "https://api.openf1.org/v1/location?session_key=\(sessionKey)&driver_number=\(driver.driver_number)&date>=\(startStr)&date<=\(endStr)"
            guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encoded) else { continue }
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
                guard let locs = try? JSONDecoder().decode([LocationPoint].self, from: data), !locs.isEmpty else { return }
                DispatchQueue.main.async {
                    self.positions[driver.driver_number] = locs
                    self.currentPosition[driver.driver_number] = locs.first
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

        let trackCenter = CGPoint(x: trackBounds.midX, y: trackBounds.midY)
        let locCenter = CGPoint(x: locationBounds.midX, y: locationBounds.midY)
        let trackVector = CGPoint(x: trackBounds.maxX - trackBounds.minX, y: trackBounds.maxY - trackBounds.minY)
        let locVector = CGPoint(x: locationBounds.maxX - locationBounds.minX, y: locationBounds.maxY - locationBounds.minY)
        let trackAngle = atan2(trackVector.y, trackVector.x)
        let locAngle = atan2(locVector.y, locVector.x)
        let rotation = trackAngle - locAngle
        let scaleX = trackBounds.width / locationBounds.width
        let scaleY = trackBounds.height / locationBounds.height
        let scale = (scaleX + scaleY) / 2

        var t = CGAffineTransform.identity
        t = t.translatedBy(x: -locCenter.x, y: -locCenter.y)
        t = t.rotated(by: rotation)
        t = t.scaledBy(x: scale, y: scale)
        t = t.translatedBy(x: trackCenter.x, y: trackCenter.y)
        locationTransform = t
    }

    func point(for loc: LocationPoint, in size: CGSize) -> CGPoint {
        let transformed = CGPoint(x: loc.x, y: loc.y).applying(locationTransform)
        let nx = (transformed.x - trackBounds.minX) / trackBounds.width
        let ny = 1 - (transformed.y - trackBounds.minY) / trackBounds.height
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }

    func start() {
        guard !isRunning else { pause(); return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.stepIndex += 1
            if self.stepIndex >= self.maxSteps {
                self.pause()
            } else {
                self.updatePositions()
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
