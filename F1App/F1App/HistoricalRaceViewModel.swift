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

struct RaceControlMessage: Identifiable, Decodable {
    let id = UUID()
    let details: [String: String]

    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = "\(intValue)"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var temp: [String: String] = [:]
        for key in container.allKeys {
            if let v = try? container.decode(String.self, forKey: key) {
                temp[key.stringValue] = v
            } else if let v = try? container.decode(Int.self, forKey: key) {
                temp[key.stringValue] = String(v)
            } else if let v = try? container.decode(Double.self, forKey: key) {
                temp[key.stringValue] = String(v)
            } else if let v = try? container.decode(Bool.self, forKey: key) {
                temp[key.stringValue] = String(v)
            } else if (try? container.decodeNil(forKey: key)) == true {
                temp[key.stringValue] = "null"
            }
        }
        details = temp
    }
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
    @Published var debugEnabled = true
    @Published var diagnosisSummary: String?
    @Published var raceControlMessages: [RaceControlMessage] = []
    let logger = DebugLogger()
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

    private func log(_ title: String, _ detail: String = "") {
        guard debugEnabled else { return }
        logger.log(title, detail)
    }

    private func previewBody(_ data: Data?, max: Int = 500) -> String {
        guard let d = data else { return "<no body>" }
        let s = String(data: d, encoding: .utf8) ?? "<non-utf8 \(d.count) bytes>"
        return s.count > max ? String(s.prefix(max)) + " …" : s
    }

    func load(for race: Race) {
        pause()
        stepIndex = 0
        positions.removeAll()
        currentPosition.removeAll()
        raceControlMessages.removeAll()
        parseTrack(race.coordinates)

        guard let yearInt = Int(year) else {
            errorMessage = "Selectează un an valid"
            return
        }
        guard let circuitId = race.circuit_id, let circuitKey = Int(circuitId) else {
            errorMessage = "Lipsește circuit_id"
            return
        }

        // Rezolvă sesiunea DOAR cu year + circuit_key
        resolveSession(year: yearInt, meetingKey: nil, circuitKey: circuitKey)
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

    private func resolveSession(year: Int, meetingKey: Int?, circuitKey: Int?) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/live/resolve")!
        var items = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "session_type", value: "Race")
        ]
        if let mk = meetingKey {
            items.append(URLQueryItem(name: "meeting_key", value: String(mk)))
        } else if let ck = circuitKey {
            items.append(URLQueryItem(name: "circuit_key", value: String(ck)))
        }
        comps.queryItems = items

        let url = comps.url!
        URLSession.shared.dataTask(with: url) { data, resp, error in
            self.log("GET /live/resolve", "url=\(url)\nerr=\(String(describing: error)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
            if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
                let body = String(data: data ?? Data(), encoding: .utf8) ?? ""
                DispatchQueue.main.async { self.errorMessage = "Resolve \(http.statusCode): \(body)" }
                return
            }
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Eroare rețea la /resolve: \(error.localizedDescription)" }
                return
            }
            guard let data = data,
                  let session = try? JSONDecoder().decode(ResolveResponse.self, from: data) else {
                DispatchQueue.main.async { self.errorMessage = "Nu am putut decoda răspunsul /resolve" }
                return
            }
            DispatchQueue.main.async {
                self.sessionKey = session.session_key
                self.sessionStart = session.date_start
                self.sessionEnd = session.date_end
                self.errorMessage = nil
                self.fetchDrivers(sessionKey: session.session_key)
                self.fetchRaceControl(sessionKey: session.session_key)
            }
        }.resume()
    }

    private struct DriversResponse: Decodable {
        let data: [DriverInfo]
    }

    private struct LocationsResponse: Decodable {
        let data: [LocationPoint]
    }

    private struct RaceControlResponse: Decodable {
        let data: [RaceControlMessage]
    }

    private func fetchDrivers(sessionKey: Int) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/drivers")!
        comps.queryItems = [URLQueryItem(name: "session_key", value: String(sessionKey))]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, resp, error in
            self.log("GET /openf1/drivers", "url=\(url)\nerr=\(String(describing: error)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Eroare rețea la /drivers: \(error.localizedDescription)" }
                return
            }
            guard let data = data else { return }
            do {
                let response = try JSONDecoder().decode(DriversResponse.self, from: data)
                let uniqueDrivers = Array(Set(response.data))
                DispatchQueue.main.async {
                    self.drivers = uniqueDrivers
                    self.fetchLocations(sessionKey: sessionKey)
                }
            } catch {
                self.log("decode /drivers", error.localizedDescription)
            }
        }.resume()
    }

    private func fetchRaceControl(sessionKey: Int) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/race_control")!
        comps.queryItems = [URLQueryItem(name: "session_key", value: String(sessionKey))]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, resp, error in
            self.log("GET /openf1/race_control", "url=\(url)\nerr=\(String(describing: error)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Eroare rețea la /race_control: \(error.localizedDescription)" }
                return
            }
            guard let data = data else { return }
            do {
                let response = try JSONDecoder().decode(RaceControlResponse.self, from: data)
                DispatchQueue.main.async { self.raceControlMessages = response.data }
            } catch {
                self.log("decode /race_control", error.localizedDescription)
            }
        }.resume()
    }

    private func fetchLocations(sessionKey: Int) {
        let backendFormatter = DateFormatter()
        backendFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        backendFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        backendFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let startString = sessionStart,
              let start = backendFormatter.date(from: startString) else { return }
        let end: Date
        if let endString = sessionEnd,
           let endDate = backendFormatter.date(from: endString) {
            end = endDate
        } else {
            end = start.addingTimeInterval(3 * 60 * 60)
        }
        let startStr = dateFormatter.string(from: start)
        let endStr = dateFormatter.string(from: end)
        locationFetchCount = 0

        for driver in drivers {
            fetchDriverLocations(driver: driver,
                                 sessionKey: sessionKey,
                                 startStr: startStr,
                                 endStr: endStr,
                                 offset: 0,
                                 accumulated: [])
        }

        func fetchDriverLocations(driver: DriverInfo,
                                  sessionKey: Int,
                                  startStr: String,
                                  endStr: String,
                                  offset: Int,
                                  accumulated: [LocationPoint]) {
            var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/location")!
            comps.queryItems = [
                URLQueryItem(name: "session_key", value: String(sessionKey)),
                URLQueryItem(name: "driver_number", value: String(driver.driver_number)),
                URLQueryItem(name: "date__gt", value: startStr),
                URLQueryItem(name: "date__lt", value: endStr),
                URLQueryItem(name: "order_by", value: "date"),
                URLQueryItem(name: "limit", value: "1000"),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            guard let url = comps.url else { return }
            URLSession.shared.dataTask(with: url) { data, resp, error in
                self.log("GET /openf1/location", "url=\(url)\nerr=\(String(describing: error)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Eroare rețea la /location: \(error.localizedDescription)"
                        self.driverFetchCompleted()
                    }
                    return
                }
                guard let data = data else {
                    DispatchQueue.main.async { self.driverFetchCompleted() }
                    return
                }
                do {
                    let response = try JSONDecoder().decode(LocationsResponse.self, from: data)
                    let converted = response.data.map { lp -> LocationPoint in
                        var isoDate = lp.date
                        if let d = backendFormatter.date(from: lp.date) {
                            isoDate = self.dateFormatter.string(from: d)
                        }
                        return LocationPoint(driver_number: lp.driver_number, date: isoDate, x: lp.x, y: lp.y)
                    }
                    let newAccum = accumulated + converted
                    if response.data.count == 1000 {
                        fetchDriverLocations(driver: driver,
                                             sessionKey: sessionKey,
                                             startStr: startStr,
                                             endStr: endStr,
                                             offset: offset + 1000,
                                             accumulated: newAccum)
                    } else {
                        DispatchQueue.main.async {
                            self.positions[driver.driver_number] = newAccum
                            self.currentPosition[driver.driver_number] = newAccum.first
                            self.driverFetchCompleted()
                        }
                    }
                } catch {
                    self.log("decode /location", error.localizedDescription)
                    DispatchQueue.main.async { self.driverFetchCompleted() }
                }
            }.resume()
        }
    }

    private func driverFetchCompleted() {
        locationFetchCount += 1
        if locationFetchCount == drivers.count {
            if errorMessage != nil {
                return
            } else if positions.isEmpty {
                errorMessage = "Date indisponibile"
            } else {
                calculateLocationBounds()
                updatePositions()
            }
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
        let newTimer = Timer(timeInterval: scaled, repeats: false) { _ in
            withAnimation(.easeInOut(duration: self.currentStepDuration)) {
                self.stepIndex += 1
                self.updatePositions()
            }
            self.scheduleNextStep()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
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

    // MARK: - Debug diagnosis

    func runDiagnosis(for race: Race) {
        diagnosisSummary = nil
        logger.clear()
        log(
          "Starting diagnosis",
          """
          year=\(year), circuit_id=\(race.circuit_id ?? "nil"), date=\(race.date) baseURL=\(APIConfig.baseURL)
          """
        )

        let healthURL = URL(string: "\(APIConfig.baseURL)/api/health")!
        URLSession.shared.dataTask(with: healthURL) { data, resp, err in
            self.log("GET /api/health", "err=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")

            guard let yearInt = Int(self.year) else {
                DispatchQueue.main.async { self.diagnosisSummary = "An invalid." }
                return
            }
            guard let circuitId = race.circuit_id, let circuitKey = Int(circuitId) else {
                DispatchQueue.main.async { self.diagnosisSummary = "Lipsește circuit_id." }
                return
            }

            var comps = URLComponents(string: "\(APIConfig.baseURL)/api/live/resolve")!
            comps.queryItems = [
                URLQueryItem(name: "year", value: String(yearInt)),
                URLQueryItem(name: "circuit_key", value: String(circuitKey)),
                URLQueryItem(name: "date", value: String(race.date.prefix(10))),
                URLQueryItem(name: "session_type", value: "Race")
            ]
            let resolveURL = comps.url!
            URLSession.shared.dataTask(with: resolveURL) { data, resp, err in
                self.log("GET /live/resolve", "url=\(resolveURL)\nerr=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
                guard err == nil, let data = data, let session = try? JSONDecoder().decode(ResolveResponse.self, from: data) else {
                    DispatchQueue.main.async { self.diagnosisSummary = "resolve a eșuat. Vezi log." }
                    return
                }
                let sk = session.session_key
                var driversComps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/drivers")!
                driversComps.queryItems = [URLQueryItem(name: "session_key", value: String(sk)), URLQueryItem(name: "limit", value: "5")]
                let driversURL = driversComps.url!
                URLSession.shared.dataTask(with: driversURL) { data, resp, err in
                    self.log("GET /openf1/drivers", "url=\(driversURL)\nerr=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
                    guard err == nil, let data = data, let dr = try? JSONDecoder().decode(DriversResponse.self, from: data) else {
                        DispatchQueue.main.async { self.diagnosisSummary = "drivers a eșuat. Vezi log." }
                        return
                    }
                    let countDrivers = dr.data.count
                    var locURLC = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/location")!
                    locURLC.queryItems = [
                        URLQueryItem(name: "session_key", value: String(sk)),
                        URLQueryItem(name: "order_by", value: "date"),
                        URLQueryItem(name: "limit", value: "1")
                    ]
                    let locURL = locURLC.url!
                    URLSession.shared.dataTask(with: locURL) { data, resp, err in
                        self.log("GET /openf1/location", "url=\(locURL)\nerr=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
                        var locCount = 0
                        if let data = data, let lr = try? JSONDecoder().decode(LocationsResponse.self, from: data) {
                            locCount = lr.data.count
                        }
                        DispatchQueue.main.async {
                            self.diagnosisSummary = "OK resolve (sk=\(sk)), drivers=\(countDrivers), location_first=\(locCount). Vezi log pentru detalii."
                        }
                    }.resume()
                }.resume()
            }.resume()
        }.resume()
    }

}

