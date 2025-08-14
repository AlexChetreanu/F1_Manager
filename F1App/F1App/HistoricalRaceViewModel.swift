import Foundation
import SwiftUI
import CoreLocation

struct Meeting: Decodable {
    let meeting_key: Int
    let date_start: String
}

struct DriverInfo: Identifiable, Decodable {
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

class HistoricalRaceViewModel: ObservableObject {
    @Published var year: String = ""
    @Published var errorMessage: String?
    @Published var meeting: Meeting?
    @Published var drivers: [DriverInfo] = []
    @Published var positions: [Int: [LocationPoint]] = [:]
    @Published var currentPosition: [Int: LocationPoint] = [:]
    @Published var isRunning = false
    @Published var trackPoints: [CGPoint] = []

    private var timer: Timer?
    private var stepIndex = 0
    private var minX: Double = 0
    private var maxX: Double = 1
    private var minY: Double = 0
    private var maxY: Double = 1

    func load(for race: Race) {
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
        minX = xs.min() ?? 0
        maxX = xs.max() ?? 1
        minY = ys.min() ?? 0
        maxY = ys.max() ?? 1
        trackPoints = arr.map { point in
            let x = (point[0] - minX) / (maxX - minX)
            let y = 1 - (point[1] - minY) / (maxY - minY)
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
                self.fetchDrivers(meetingKey: meeting.meeting_key)
            }
        }.resume()
    }

    private func fetchDrivers(meetingKey: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/drivers?meeting_key=\(meetingKey)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let drivers = try? JSONDecoder().decode([DriverInfo].self, from: data) else { return }
            DispatchQueue.main.async {
                self.drivers = drivers
                self.fetchLocations()
            }
        }.resume()
    }

    private func fetchLocations() {
        guard let meeting = meeting else { return }
        let formatter = ISO8601DateFormatter()
        guard let start = formatter.date(from: meeting.date_start) else { return }
        let end = start.addingTimeInterval(3 * 60 * 60)
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        for driver in drivers {
            let urlString = "https://api.openf1.org/v1/location?meeting_key=\(meeting.meeting_key)&driver_number=\(driver.driver_number)&date>=\(startStr)&date<=\(endStr)"
            guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encoded) else { continue }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data,
                      let locs = try? JSONDecoder().decode([LocationPoint].self, from: data),
                      !locs.isEmpty else { return }
                DispatchQueue.main.async {
                    self.positions[driver.driver_number] = locs
                    self.currentPosition[driver.driver_number] = locs.first
                }
            }.resume()
        }
    }

    func point(for loc: LocationPoint, in size: CGSize) -> CGPoint {
        let nx = (loc.x - minX) / (maxX - minX)
        let ny = 1 - (loc.y - minY) / (maxY - minY)
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }

    func start() {
        guard !isRunning else { pause(); return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.stepIndex += 1
            for driver in self.drivers {
                if let arr = self.positions[driver.driver_number], self.stepIndex < arr.count {
                    self.currentPosition[driver.driver_number] = arr[self.stepIndex]
                }
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func year(from iso: String) -> Int {
        return Int(iso.prefix(4)) ?? 0
    }
}
