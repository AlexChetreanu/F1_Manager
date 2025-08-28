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

struct StrategySuggestion: Identifiable, Decodable {
    let driver_number: Int?
    let driver_name: String?
    let team: String?
    let position: Int?
    let advice: String
    let why: String

    var id: Int { driver_number ?? Int.random(in: 1000...9999) }
}

struct StrategyResponse: Decodable {
    let suggestions: [StrategySuggestion]?
    let suggestion: StrategySuggestion?
    let error: String?
}

func loadStrategy(meeting: Int, retry: Int = 0) async -> [StrategySuggestion] {
    let url = API.historicalBaseURL.appendingPathComponent("/api/historical/meeting/\(meeting)/strategy")
    do {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse else { return [] }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 429, retry < 3 {
                print("Strategy HTTP 429: \(body)")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return await loadStrategy(meeting: meeting, retry: retry + 1)
            } else {
                print("Strategy HTTP \(http.statusCode): \(body)")
                return []
            }
        }
        let decoded = try JSONDecoder().decode(StrategyResponse.self, from: data)
        if let list = decoded.suggestions { return list }
        if let one = decoded.suggestion { return [one] }
        return []
    } catch {
        return []
    }
}

struct Envelope<T: Decodable>: Decodable {
    let data: T
    let limit: Int?
    let offset: Int?
}

struct SessionDTO: Decodable {
    let session_key: Int
    let meeting_key: Int?
    let session_name: String?
    let session_type: String?
    let date_start: String?
    let date_end: String?
    let gmt_offset: String?
}

@discardableResult
private func fetchEnvelope<T: Decodable>(_ url: URL) async throws -> T {
    let env: Envelope<T> = try await fetchDecodable(url)
    return env.data
}

private func fetchDecodable<T: Decodable>(_ url: URL) async throws -> T {
    var req = URLRequest(url: url)
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("F1App iOS", forHTTPHeaderField: "User-Agent")
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    if http.statusCode == 429 {
        let head = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
        print("HTTP 429 for \(url): \(head)")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return try await fetchDecodable(url)
    }
    guard http.statusCode == 200 else {
        let head = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
        print("HTTP \(http.statusCode) for \(url): \(head)")
        throw NSError(domain: "HTTP", code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(head)"])
    }
    return try JSONDecoder().decode(T.self, from: data)
}

private func seconds(from gmtOffset: String?) -> Int {
    guard let s = gmtOffset, s.count >= 6 else { return 0 }
    let sign = s.first == "-" ? -1 : 1
    let parts = s.dropFirst().split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return 0 }
    let secs = (parts[0] * 3600) + (parts[1] * 60) + (parts.count > 2 ? parts[2] : 0)
    return sign * secs
}

private func parseLocalDate(_ str: String?, gmtOffset: String?) -> Date? {
    guard let str = str else { return nil }
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = str.contains(".") ? "yyyy-MM-dd HH:mm:ss.SSSSSS" : "yyyy-MM-dd HH:mm:ss"
    df.timeZone = TimeZone(secondsFromGMT: seconds(from: gmtOffset))
    return df.date(from: str)
}

private let isoUTC: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

class HistoricalRaceViewModel: ObservableObject {
    @Published var year: String = ""
    @Published var errorMessage: String?
    @Published var drivers: [DriverInfo] = []
    @Published var positions: [Int: [LocationPoint]] = [:]
    @Published var currentPosition: [Int: LocationPoint] = [:]
    @Published var isRunning = false
    @Published var trackPoints: [CGPoint] = []
    @Published var sessionKey: Int?
    @Published var meetingKey: Int?
    @Published var sessionStart: String?
    @Published var sessionEnd: String?
    @Published var stepIndex: Int = 0
    @Published var playbackSpeed: Double = 1.0
    @Published var currentStepDuration: Double = 1.0
    @Published var debugEnabled = true
    @Published var diagnosisSummary: String?
    @Published var currentEventMessage: String?
    @Published var strategySuggestions: [StrategySuggestion] = []
    @Published var snapshot: LiveSnapshot?
    private var allRaceControlMessages: [RaceEventDTO] = []
    private var allOvertakes: [RaceEventDTO] = []
    private var nextRaceControlIndex = 0
    private var nextOvertakeIndex = 0
    private var sessionStartDate: Date?
    private var sessionEndDate: Date?
    private struct ActiveToast: Identifiable {
        let id: Int64
        let event: RaceEventDTO
        let expiresAtMs: Int64
    }
    private var activeToasts: [ActiveToast] = []
    private let toastLifetimeMs: Int64 = 20_000
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
    private var strategyTimer: Timer?
    private let snapshotService = HistoricalSnapshotService()

    private func log(_ title: String, _ detail: String = "") {
        guard debugEnabled else { return }
        logger.log(title, detail)
    }

    private func previewBody(_ data: Data?, max: Int = 500) -> String {
        guard let d = data else { return "<no body>" }
        let s = String(data: d, encoding: .utf8) ?? "<non-utf8 \(d.count) bytes>"
        return s.count > max ? String(s.prefix(max)) + " …" : s
    }

    func startStrategyUpdates(meetingKey: Int) {
        log("Start strategy updates", "meeting: \(meetingKey)")
        strategyTimer?.invalidate()
        strategyTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.fetchStrategy(meetingKey: meetingKey)
        }
        strategyTimer?.tolerance = 5
        fetchStrategy(meetingKey: meetingKey)
    }

    func stopStrategyUpdates() {
        log("Stop strategy updates")
        strategyTimer?.invalidate()
        strategyTimer = nil
    }

    private func fetchStrategy(meetingKey: Int) {
        log("Fetching strategy", "meeting: \(meetingKey)")
        Task {
            let list = await loadStrategy(meeting: meetingKey)
            await MainActor.run { self.strategySuggestions = list }
            if list.isEmpty {
                await MainActor.run { self.errorMessage = "Nu pot prelua strategia" }
                log("Strategy fetch failed", "empty response")
            } else {
                log("Strategy bot returned \(list.count) suggestions")
                for s in list {
                    let name = s.driver_name ?? "?"
                    let advice = s.advice
                    let reason = s.why
                    log("Suggestion for \(name)", "\(advice) – \(reason)")
                }
            }
        }
    }

    func load(for race: Race) {
        pause()
        stepIndex = 0
        positions.removeAll()
        currentPosition.removeAll()
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

    private func resolveSession(year: Int, meetingKey: Int?, circuitKey: Int?) {
        var comps = URLComponents(string: "\(API.base)/api/openf1/sessions")!
        var items = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "session_type", value: "Race"),
            URLQueryItem(name: "order_by", value: "date_start")
        ]
        if let mk = meetingKey {
            items.append(URLQueryItem(name: "meeting_key", value: String(mk)))
        }
        if let ck = circuitKey {
            items.append(URLQueryItem(name: "circuit_key", value: String(ck)))
        }
        comps.queryItems = items

        guard let url = comps.url else { return }
        RequestThrottler.shared.execute {
            Task {
                self.log("GET /openf1/sessions (local)", "url=\(url)")
                do {
                    let sessions: [SessionDTO] = try await fetchEnvelope(url)
                    guard let session = sessions.last(where: { ($0.session_name ?? "").lowercased().contains("race") }) ?? sessions.last else {
                        await MainActor.run { self.errorMessage = "Nu am putut decoda răspunsul /sessions" }
                        return
                    }
                    let startDate = parseLocalDate(session.date_start, gmtOffset: session.gmt_offset)
                    let endDate = parseLocalDate(session.date_end, gmtOffset: session.gmt_offset)
                    await MainActor.run {
                        self.sessionKey = session.session_key
                        self.meetingKey = session.meeting_key
                        self.sessionStart = session.date_start
                        self.sessionEnd = session.date_end
                        self.sessionStartDate = startDate
                        self.sessionEndDate = endDate
                        self.errorMessage = nil
                        self.fetchDrivers(sessionKey: session.session_key)
                        if self.sessionStartDate != nil {
                            self.fetchRaceControl(sessionKey: session.session_key)
                            self.fetchOvertakes(sessionKey: session.session_key)
                        }
                    }
                } catch {
                    await MainActor.run { self.errorMessage = "Nu am putut decoda răspunsul /sessions" }
                }
            }
        }
    }

    private func fetchDrivers(sessionKey: Int) {
        var comps = URLComponents(string: "\(API.base)/api/openf1/drivers")!
        comps.queryItems = [URLQueryItem(name: "session_key", value: String(sessionKey))]
        guard let url = comps.url else { return }
        RequestThrottler.shared.execute {
            Task {
                self.log("GET /openf1/drivers", "url=\(url)")
                do {
                    let response: [DriverInfo] = try await fetchEnvelope(url)
                    let uniqueDrivers = Array(Set(response))
                    await MainActor.run {
                        self.drivers = uniqueDrivers
                        self.fetchLocations(sessionKey: sessionKey)
                    }
                } catch {
                    await MainActor.run { self.errorMessage = "Eroare rețea la /drivers: \(error.localizedDescription)" }
                }
            }
        }
    }

    private func fetchRaceControl(sessionKey: Int) {
        var comps = URLComponents(string: "\(API.base)/api/openf1/race_control")!
        comps.queryItems = [URLQueryItem(name: "session_key", value: String(sessionKey))]
        guard let url = comps.url else { return }
        RequestThrottler.shared.execute {
            Task {
                self.log("GET /openf1/race_control", "url=\(url)")
                do {
                    let response: [RaceEventDTO] = try await fetchEnvelope(url)
                    let sorted: [RaceEventDTO]
                    if let start = self.sessionStartDate {
                        sorted = response.sorted {
                            (eventTimeMs($0, sessionStart: start) ?? .max) < (eventTimeMs($1, sessionStart: start) ?? .max)
                        }
                    } else {
                        sorted = response.sorted {
                            ($0.dateIso ?? $0.date ?? "") < ($1.dateIso ?? $1.date ?? "")
                        }
                    }
                    await MainActor.run {
                        self.allRaceControlMessages = sorted
                        self.nextRaceControlIndex = 0
                        self.log("race_control fetched", "count=\(sorted.count)")
                    }
                } catch {
                    await MainActor.run { self.errorMessage = "Eroare rețea la /race_control: \(error.localizedDescription)" }
                }
            }
        }
    }

    private func fetchOvertakes(sessionKey: Int) {
        var comps = URLComponents(string: "\(API.base)/api/openf1/overtakes")!
        comps.queryItems = [URLQueryItem(name: "session_key", value: String(sessionKey))]
        guard let url = comps.url else { return }
        RequestThrottler.shared.execute {
            Task {
                self.log("GET /openf1/overtakes", "url=\(url)")
                do {
                    let response: [RaceEventDTO] = try await fetchEnvelope(url)
                    let sorted: [RaceEventDTO]
                    if let start = self.sessionStartDate {
                        sorted = response.sorted {
                            (eventTimeMs($0, sessionStart: start) ?? .max) < (eventTimeMs($1, sessionStart: start) ?? .max)
                        }
                    } else {
                        sorted = response.sorted {
                            ($0.dateIso ?? $0.date ?? "") < ($1.dateIso ?? $1.date ?? "")
                        }
                    }
                    await MainActor.run {
                        self.allOvertakes = sorted
                        self.nextOvertakeIndex = 0
                        self.log("overtakes fetched", "count=\(sorted.count)")
                    }
                } catch {
                    await MainActor.run { self.errorMessage = "Eroare rețea la /overtakes: \(error.localizedDescription)" }
                }
            }
        }
    }

    private func fetchLocations(sessionKey: Int) {
        let margin: TimeInterval = 120
        let baseStart = sessionStartDate ?? Date()
        let baseEnd = sessionEndDate ?? baseStart.addingTimeInterval(4 * 3600)
        locationFetchCount = 0

        for driver in drivers {
            fetchDriverLocations(driver: driver,
                                 sessionKey: sessionKey,
                                 margin: margin,
                                 offset: 0,
                                 accumulated: [],
                                 expanded: false)
        }

        func fetchDriverLocations(driver: DriverInfo,
                                  sessionKey: Int,
                                  margin: TimeInterval,
                                  offset: Int,
                                  accumulated: [LocationPoint],
                                  expanded: Bool) {
            let start = baseStart.addingTimeInterval(-margin)
            let end = baseEnd.addingTimeInterval(+margin)
            let startStr = isoUTC.string(from: start)
            let endStr = isoUTC.string(from: end)
            var comps = URLComponents(string: "\(API.base)/api/openf1/location")!
            comps.queryItems = [
                URLQueryItem(name: "session_key", value: String(sessionKey)),
                URLQueryItem(name: "driver_number", value: String(driver.driver_number)),
                URLQueryItem(name: "date__gte", value: startStr),
                URLQueryItem(name: "date__lte", value: endStr),
                URLQueryItem(name: "order_by", value: "date"),
                URLQueryItem(name: "limit", value: "1000"),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            guard let url = comps.url else { return }
            RequestThrottler.shared.execute {
                Task {
                    self.log("GET /openf1/location", "url=\(url)")
                    do {
                        let response: [LocationPoint] = try await fetchEnvelope(url)
                        if response.isEmpty && offset == 0 {
                            var probeComps = URLComponents(string: "\(API.base)/api/openf1/location")!
                            probeComps.queryItems = [
                                URLQueryItem(name: "session_key", value: String(sessionKey)),
                                URLQueryItem(name: "driver_number", value: String(driver.driver_number)),
                                URLQueryItem(name: "limit", value: "1")
                            ]
                            if let probeURL = probeComps.url {
                                do {
                                    let probe: [LocationPoint] = try await fetchEnvelope(probeURL)
                                    if probe.isEmpty {
                                        await MainActor.run {
                                            self.errorMessage = "No location data for this session."
                                            self.driverFetchCompleted()
                                        }
                                    } else if !expanded {
                                        fetchDriverLocations(driver: driver,
                                                             sessionKey: sessionKey,
                                                             margin: 600,
                                                             offset: 0,
                                                             accumulated: [],
                                                             expanded: true)
                                    } else {
                                        await MainActor.run { self.driverFetchCompleted() }
                                    }
                                } catch {
                                    await MainActor.run { self.driverFetchCompleted() }
                                }
                            } else {
                                await MainActor.run { self.driverFetchCompleted() }
                            }
                            return
                        }
                        let converted = response.map { lp -> LocationPoint in
                            var isoDate = lp.date
                            if let d = self.backendFormatter.date(from: lp.date) {
                                isoDate = self.dateFormatter.string(from: d)
                            }
                            return LocationPoint(driver_number: lp.driver_number, date: isoDate, x: lp.x, y: lp.y)
                        }
                        let newAccum = accumulated + converted
                        if response.count == 1000 {
                            fetchDriverLocations(driver: driver,
                                                 sessionKey: sessionKey,
                                                 margin: margin,
                                                 offset: offset + 1000,
                                                 accumulated: newAccum,
                                                 expanded: expanded)
                        } else {
                            await MainActor.run {
                                var processed = newAccum
                                if newAccum.count > 2,
                                   let startDate = self.dateFormatter.date(from: newAccum[0].date) {
                                    let resampler = PositionResampler()
                                    let samples: [PositionSample] = newAccum.compactMap { lp in
                                        guard let d = self.dateFormatter.date(from: lp.date) else { return nil }
                                        let t = d.timeIntervalSince(startDate)
                                        return PositionSample(t: t, x: lp.x, y: lp.y)
                                    }
                                    let smoothed = resampler.resample(samples: samples)
                                    processed = smoothed.map { s in
                                        let date = startDate.addingTimeInterval(s.t)
                                        let iso = self.dateFormatter.string(from: date)
                                        return LocationPoint(driver_number: driver.driver_number, date: iso, x: s.x, y: s.y)
                                    }
                                }
                                self.positions[driver.driver_number] = processed
                                self.currentPosition[driver.driver_number] = processed.first
                                self.driverFetchCompleted()
                            }
                        }
                    } catch {
                        await MainActor.run { self.driverFetchCompleted() }
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
        if let start = sessionStartDate, let current = currentRaceDate() {
            let nowMs = Int64(current.timeIntervalSince(start) * 1000)
            onPlaybackTick(nowMs: nowMs)
        }
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


    private func scheduleNextStep() {
        guard isRunning, stepIndex < maxSteps - 1,
              let interval = timeIntervalForStep(stepIndex) else {
            pause()
            return
        }
        let scaled = interval / playbackSpeed
        currentStepDuration = scaled
        let newTimer = Timer(timeInterval: scaled, repeats: false) { _ in
            withAnimation(.linear(duration: self.currentStepDuration)) {
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
          year=\(year), circuit_id=\(race.circuit_id ?? "nil"), date=\(race.date) baseURL=\(API.base)
          """
        )

        let healthURL = URL(string: "\(API.base)/api/health")!
        URLSession.shared.dataTask(with: healthURL) { (data: Data?, resp: URLResponse?, err: Error?) in
            self.log("GET /api/health", "err=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")

            guard let yearInt = Int(self.year) else {
                DispatchQueue.main.async { self.diagnosisSummary = "An invalid." }
                return
            }
            guard let circuitId = race.circuit_id, let circuitKey = Int(circuitId) else {
                DispatchQueue.main.async { self.diagnosisSummary = "Lipsește circuit_id." }
                return
            }

            var comps = URLComponents(string: "\(API.base)/api/openf1/sessions")!
            comps.queryItems = [
                URLQueryItem(name: "year", value: String(yearInt)),
                URLQueryItem(name: "session_type", value: "Race"),
                URLQueryItem(name: "order_by", value: "date_start"),
                URLQueryItem(name: "circuit_key", value: String(circuitKey))
            ]
            let resolveURL = comps.url!
            URLSession.shared.dataTask(with: resolveURL) { (data: Data?, resp: URLResponse?, err: Error?) in
                self.log("GET /openf1/sessions (local)", "url=\(resolveURL)\nerr=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
                guard err == nil,
                      let data = data,
                      let env = try? JSONDecoder().decode(Envelope<[SessionDTO]>.self, from: data),
                      let session = env.data.last else {
                    DispatchQueue.main.async { self.diagnosisSummary = "sessions a eșuat. Vezi log." }
                    return
                }
                let sk = session.session_key
                var driversComps = URLComponents(string: "\(API.base)/api/openf1/drivers")!
                driversComps.queryItems = [URLQueryItem(name: "session_key", value: String(sk)), URLQueryItem(name: "limit", value: "5")]
                let driversURL = driversComps.url!
                URLSession.shared.dataTask(with: driversURL) { (data: Data?, resp: URLResponse?, err: Error?) in
                    self.log("GET /openf1/drivers", "url=\(driversURL)\nerr=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
                    guard err == nil, let data = data, let drEnv = try? JSONDecoder().decode(Envelope<[DriverInfo]>.self, from: data) else {
                        DispatchQueue.main.async { self.diagnosisSummary = "drivers a eșuat. Vezi log." }
                        return
                    }
                    let countDrivers = drEnv.data.count
                    var locURLC = URLComponents(string: "\(API.base)/api/openf1/location")!
                    locURLC.queryItems = [
                        URLQueryItem(name: "session_key", value: String(sk)),
                        URLQueryItem(name: "order_by", value: "date"),
                        URLQueryItem(name: "limit", value: "1")
                    ]
                    let locURL = locURLC.url!
                    URLSession.shared.dataTask(with: locURL) { (data: Data?, resp: URLResponse?, err: Error?) in
                        self.log("GET /openf1/location", "url=\(locURL)\nerr=\(String(describing: err)) status=\((resp as? HTTPURLResponse)?.statusCode ?? -1)\n\(self.previewBody(data))")
                        var locCount = 0
                        if let data = data, let lrEnv = try? JSONDecoder().decode(Envelope<[LocationPoint]>.self, from: data) {
                            locCount = lrEnv.data.count
                        }
                        DispatchQueue.main.async {
                            self.diagnosisSummary = "OK sessions (sk=\(sk)), drivers=\(countDrivers), location_first=\(locCount). Vezi log pentru detalii."
                        }
                    }.resume()
                }.resume()
            }.resume()
        }//.resume()
    }

    func loadSnapshot(forYear year: Int) {
        snapshotService.fetchSnapshot(year: year) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let snap):
                    self.snapshot = snap
                    self.drivers = snap.drivers.map {
                        DriverInfo(driver_number: $0.driver_number,
                                   full_name: $0.name,
                                   team_color: $0.team_colour,
                                   team_name: $0.team_name)
                    }
                    self.currentPosition = Dictionary(uniqueKeysWithValues: snap.drivers.compactMap { state in
                        guard let loc = state.location else { return nil }
                        let lp = LocationPoint(driver_number: state.driver_number, date: snap.ts ?? "", x: loc.x ?? 0, y: loc.y ?? 0)
                        return (state.driver_number, lp)
                    })
                    self.errorMessage = nil
                case .failure(let err):
                    self.errorMessage = err.localizedDescription
                }
            }
        }
    }
}

