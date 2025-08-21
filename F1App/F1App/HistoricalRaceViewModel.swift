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
    @Published var interpolatedPosition: [Int: TimedPoint] = [:]
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
    @Published var currentEventMessage: String?
    @Published var showDriverDots: Bool = false
    @Published var nowMs: Double = 0
    @Published var raceDurationMs: Double = 0
    private var allRaceControlMessages: [RaceEventDTO] = []
    private var allOvertakes: [RaceEventDTO] = []
    private var nextRaceControlIndex = 0
    private var nextOvertakeIndex = 0
    private var sessionStartDate: Date?
    private struct ActiveToast: Identifiable {
        let id: Int64
        let event: RaceEventDTO
        let expiresAtMs: Int64
    }
    private var activeToasts: [ActiveToast] = []
    private let toastLifetimeMs: Int64 = 20_000
    let logger = DebugLogger()
    private var playbackTimer: Timer?
    private var lastTick: Date?
    private var locationSamples: [Int: [TimedPoint]] = [:]
    private let speedOptions: [Double] = [1, 2, 5]
    private var speedIndex = 0
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    private let backendFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        return f
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
        interpolatedPosition.removeAll()
        locationSamples.removeAll()
        nowMs = 0
        raceDurationMs = 0
        currentEventMessage = nil
        allRaceControlMessages.removeAll()
        allOvertakes.removeAll()
        nextRaceControlIndex = 0
        nextOvertakeIndex = 0
        activeToasts.removeAll()
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
                if let ds = session.date_start {
                    self.sessionStartDate = self.backendFormatter.date(from: ds)
                } else {
                    self.sessionStartDate = nil
                }
                self.sessionEnd = session.date_end
                self.errorMessage = nil
                self.fetchDrivers(sessionKey: session.session_key)
                if self.sessionStartDate != nil {
                    self.fetchRaceControl(sessionKey: session.session_key)
                    self.fetchOvertakes(sessionKey: session.session_key)
                }
            }
        }.resume()
    }

    private struct DriversResponse: Decodable {
        let data: [DriverInfo]
    }

    private struct LocationsResponse: Decodable {
        let data: [LocationPoint]
    }

    private struct EventsResponse: Decodable {
        let data: [RaceEventDTO]
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
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(EventsResponse.self, from: data)
                let sorted: [RaceEventDTO]
                if let start = self.sessionStartDate {
                    sorted = response.data.sorted {
                        (eventTimeMs($0, sessionStart: start) ?? .max) < (eventTimeMs($1, sessionStart: start) ?? .max)
                    }
                } else {
                    sorted = response.data.sorted {
                        ($0.dateIso ?? $0.date ?? "") < ($1.dateIso ?? $1.date ?? "")
                    }
                }
                DispatchQueue.main.async {
                    self.allRaceControlMessages = sorted
                    self.nextRaceControlIndex = 0
                    self.log("race_control fetched", "count=\(sorted.count)")
                }
            } catch {
                self.log("decode /race_control", error.localizedDescription)
            }
        }.resume()
    }

    private func fetchOvertakes(sessionKey: Int) {
        var comps = URLComponents(string: "\(APIConfig.baseURL)/api/openf1/overtakes")!
        comps.queryItems = [URLQueryItem(name: "session_key", value: String(sessionKey))]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, resp, error in
            self.log("GET /openf1/overtakes", "url=\(url)\nerr=\(String(describing: error)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Eroare rețea la /overtakes: \(error.localizedDescription)" }
                return
            }
            guard let data = data else { return }
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let response = try decoder.decode(EventsResponse.self, from: data)
                let sorted: [RaceEventDTO]
                if let start = self.sessionStartDate {
                    sorted = response.data.sorted {
                        (eventTimeMs($0, sessionStart: start) ?? .max) < (eventTimeMs($1, sessionStart: start) ?? .max)
                    }
                } else {
                    sorted = response.data.sorted {
                        ($0.dateIso ?? $0.date ?? "") < ($1.dateIso ?? $1.date ?? "")
                    }
                }
                DispatchQueue.main.async {
                    self.allOvertakes = sorted
                    self.nextOvertakeIndex = 0
                    self.log("overtakes fetched", "count=\(sorted.count)")
                }
            } catch {
                self.log("decode /overtakes", error.localizedDescription)
            }
        }.resume()
    }

    private func fetchLocations(sessionKey: Int) {
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
                                 accumulatedLP: [],
                                 accumulatedTP: [])
        }

        func fetchDriverLocations(driver: DriverInfo,
                                  sessionKey: Int,
                                  startStr: String,
                                  endStr: String,
                                  offset: Int,
                                  accumulatedLP: [LocationPoint],
                                  accumulatedTP: [TimedPoint]) {
            TrackPositionService.shared.fetchLocations(sessionKey: sessionKey,
                                                       driverNumber: driver.driver_number,
                                                       dateGtISO: startStr,
                                                       dateLtISO: endStr,
                                                       limit: 1000,
                                                       offset: offset) { result in
                switch result {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.errorMessage = "Eroare rețea la /location: \(error.localizedDescription)"
                        self.driverFetchCompleted()
                    }
                case .success(let locs):
                    let lp = locs.map { dl -> LocationPoint in
                        LocationPoint(driver_number: dl.driverNumber,
                                      date: dl.dateIso,
                                      x: Double(dl.x),
                                      y: Double(dl.y))
                    }
                    let tp = locs.compactMap { dl -> TimedPoint? in
                        guard let d = TrackPositionService.parseISO(dl.dateIso) else { return nil }
                        return TimedPoint(t: d.timeIntervalSince1970, x: Double(dl.x), y: Double(dl.y))
                    }
                    let newLP = accumulatedLP + lp
                    let newTP = accumulatedTP + tp
                    if locs.count == 1000 {
                        fetchDriverLocations(driver: driver,
                                             sessionKey: sessionKey,
                                             startStr: startStr,
                                             endStr: endStr,
                                             offset: offset + 1000,
                                             accumulatedLP: newLP,
                                             accumulatedTP: newTP)
                    } else {
                        DispatchQueue.main.async {
                            self.positions[driver.driver_number] = newLP
                            self.locationSamples[driver.driver_number] = newTP.sorted { $0.t < $1.t }
                            if let first = newTP.first {
                                self.interpolatedPosition[driver.driver_number] = first
                            }
                            self.driverFetchCompleted()
                        }
                    }
                }
            }
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
                if let minT = locationSamples.values.flatMap({ $0.map { $0.t } }).min(),
                   let maxT = locationSamples.values.flatMap({ $0.map { $0.t } }).max() {
                    raceDurationMs = (maxT - minT) * 1000
                }
                updateInterpolatedPositions()
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

    public func point(forInterpolated loc: TimedPoint, in size: CGSize) -> CGPoint {
        guard locationBounds.width != 0, locationBounds.height != 0 else { return .zero }
        let rawX = (loc.x - locationBounds.minX) / locationBounds.width
        let rawY = 1 - (loc.y - locationBounds.minY) / locationBounds.height
        let nx = max(0, min(rawX, 1))
        let ny = max(0, min(rawY, 1))
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }

    func start() {
        guard !isRunning else { pause(); return }
        isRunning = true
        lastTick = Date()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        isRunning = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func cycleSpeed() {
        speedIndex = (speedIndex + 1) % speedOptions.count
        playbackSpeed = speedOptions[speedIndex]
    }

    var maxSteps: Int {
        positions.values.map { $0.count }.max() ?? 0
    }

    func updatePositions() {
        updateInterpolatedPositions()
    }

    private func tick() {
        guard isRunning else { return }
        let now = Date()
        if let last = lastTick {
            let delta = now.timeIntervalSince(last)
            nowMs += delta * playbackSpeed * 1000
            if raceDurationMs > 0 {
                nowMs = min(nowMs, raceDurationMs)
            }
        }
        lastTick = now
        updateInterpolatedPositions()
        onPlaybackTick(nowMs: Int64(nowMs))
    }

    private func updateInterpolatedPositions() {
        guard let start = sessionStartDate else { return }
        let nowAbs = start.addingTimeInterval(nowMs/1000)
        let t = nowAbs.timeIntervalSince1970
        for (driver, samples) in locationSamples {
            if let interp = PositionInterpolator.interpolate(at: t, samples: samples) {
                interpolatedPosition[driver] = TimedPoint(t: t, x: interp.x, y: interp.y)
            }
        }
    }

    func seek(to ms: Double) {
        nowMs = ms
        updateInterpolatedPositions()
        onPlaybackTick(nowMs: Int64(nowMs))
    }

    private func currentRaceDate() -> Date? {
        for arr in positions.values {
            if stepIndex < arr.count {
                return dateFormatter.date(from: arr[stepIndex].date)
            }
        }
        return nil
    }

    func onPlaybackTick(nowMs: Int64) {
        guard let start = sessionStartDate else { return }

        activeToasts.removeAll { $0.expiresAtMs <= nowMs }

        while nextRaceControlIndex < allRaceControlMessages.count {
            let e = allRaceControlMessages[nextRaceControlIndex]
            guard let t = eventTimeMs(e, sessionStart: start) else { nextRaceControlIndex += 1; continue }

            if t <= nowMs && nowMs < t + toastLifetimeMs {
                enqueueToast(for: e, expiresAtMs: t + toastLifetimeMs)
                nextRaceControlIndex += 1
            } else if t > nowMs {
                break
            } else {
                nextRaceControlIndex += 1
            }
        }

        while nextOvertakeIndex < allOvertakes.count {
            let e = allOvertakes[nextOvertakeIndex]
            guard let t = eventTimeMs(e, sessionStart: start) else { nextOvertakeIndex += 1; continue }

            if t <= nowMs && nowMs < t + toastLifetimeMs {
                enqueueToast(for: e, expiresAtMs: t + toastLifetimeMs)
                nextOvertakeIndex += 1
            } else if t > nowMs {
                break
            } else {
                nextOvertakeIndex += 1
            }
        }

        currentEventMessage = activeToasts.first?.event.renderedText
    }

    private func enqueueToast(for e: RaceEventDTO, expiresAtMs: Int64) {
        guard activeToasts.count < 3 else { return }
        activeToasts.append(.init(id: e.id, event: e, expiresAtMs: expiresAtMs))
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

