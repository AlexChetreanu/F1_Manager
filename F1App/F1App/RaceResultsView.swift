import SwiftUI

struct MeetingEntry: Decodable {
    let meeting_key: Int
}

struct SessionEntry: Decodable {
    let session_key: Int
    let session_type: String
    let session_name: String?
    let date_start: String?
}

enum GapToLeader: Decodable {
    case seconds(Double)
    case laps(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self = .seconds(value)
        } else if let str = try? container.decode(String.self) {
            self = .laps(str)
        } else {
            throw DecodingError.typeMismatch(
                GapToLeader.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Expected Double or String for gap_to_leader")
            )
        }
    }
}

struct SessionResultEntry: Identifiable, Decodable {
    let position: Int?
    let driver_number: Int?
    let session_key: Int?
    let dnf: Bool?
    let gap_to_leader: GapToLeader?
    var id: Int { (driver_number ?? Int.random(in: 1000...9999)) ^ (session_key ?? 0) }
}

struct RaceResultsView: View {
    let race: Race
    @ObservedObject var viewModel: HistoricalRaceViewModel
    @State private var results: [SessionResultEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                Text("Se încarcă…")
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else {
                PodiumView(entries: Array(results.prefix(3)), viewModel: viewModel)
                Divider()
                ForEach(results.dropFirst(3)) { entry in
                    HStack {
                        Text("\(entry.position ?? 0)")
                            .frame(width: 24, alignment: .trailing)
                        Text(driverName(for: entry.driver_number))
                        Spacer()
                        if entry.dnf == true {
                            Text("DNF")
                                .foregroundColor(.red)
                        } else {
                            Text(gapText(for: entry.gap_to_leader))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .onAppear {
            if results.isEmpty && race.status.lowercased() == "finished" {
                fetchResults()
            }
        }
    }

    // MARK: - Network helpers

    private func fetchDecodable<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("F1App iOS", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            let head = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw NSError(domain: "OpenF1", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode). Body: \(head)"])
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch {
            let head = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            print("⛔️ Decode failed for \(url.absoluteString): \(error)\nBody head: \(head)")
            throw error
        }
    }

    private func fetchMeetingKey(year: Int, circuitKey: Int) async throws -> Int {
        var comps = URLComponents(string: "\(openF1BaseURL)/meetings")!
        comps.queryItems = [
            .init(name: "year", value: String(year)),
            .init(name: "circuit_key", value: String(circuitKey))
        ]
        let url = comps.url!
        print("🌐 meetings URL:", url.absoluteString)

        let meetings: [MeetingEntry] = try await fetchDecodable(url)
        guard let mk = meetings.last?.meeting_key ?? meetings.first?.meeting_key else {
            throw NSError(domain: "OpenF1", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Nu am găsit meeting pentru year/circuit_key"])
        }
        return mk
    }

    private func fetchRaceSessionKey(meetingKey: Int) async throws -> Int {
        // Try 1: session_type=Race
        do {
            var c1 = URLComponents(string: "\(openF1BaseURL)/sessions")!
            c1.queryItems = [
                .init(name: "meeting_key", value: String(meetingKey)),
                .init(name: "session_type", value: "Race")
            ]
            let url1 = c1.url!
            print("🌐 sessions URL (type=Race):", url1.absoluteString)
            let s1: [SessionEntry] = try await fetchDecodable(url1)
            if let sk = s1.last?.session_key { return sk }
        } catch {
            print("⚠️ sessions(type=Race) failed: \(error.localizedDescription)")
        }

        // Try 2: session_type=RACE
        do {
            var c2 = URLComponents(string: "\(openF1BaseURL)/sessions")!
            c2.queryItems = [
                .init(name: "meeting_key", value: String(meetingKey)),
                .init(name: "session_type", value: "RACE")
            ]
            let url2 = c2.url!
            print("🌐 sessions URL (type=RACE):", url2.absoluteString)
            let s2: [SessionEntry] = try await fetchDecodable(url2)
            if let sk = s2.last?.session_key { return sk }
        } catch {
            print("⚠️ sessions(type=RACE) failed: \(error.localizedDescription)")
        }

        // Try 3: session_name=Race
        do {
            var c3 = URLComponents(string: "\(openF1BaseURL)/sessions")!
            c3.queryItems = [
                .init(name: "meeting_key", value: String(meetingKey)),
                .init(name: "session_name", value: "Race")
            ]
            let url3 = c3.url!
            print("🌐 sessions URL (name=Race):", url3.absoluteString)
            let s3: [SessionEntry] = try await fetchDecodable(url3)
            if let sk = s3.last?.session_key { return sk }
        } catch {
            print("⚠️ sessions(name=Race) failed: \(error.localizedDescription)")
        }

        // Try 4: fără filtru de tip/nume — ia ultima sesiune a meetingului
        var c4 = URLComponents(string: "\(openF1BaseURL)/sessions")!
        c4.queryItems = [
            .init(name: "meeting_key", value: String(meetingKey))
        ]
        let url4 = c4.url!
        print("🌐 sessions URL (no type/name):", url4.absoluteString)
        let s4: [SessionEntry] = try await fetchDecodable(url4)
        if let sk = s4.last?.session_key { return sk }

        throw NSError(domain: "OpenF1", code: -2,
                      userInfo: [NSLocalizedDescriptionKey: "Nu am găsit sesiunea Race pentru meeting_key \(meetingKey)"])
    }

    private func fetchSessionResults(sessionKey: Int) async throws -> [SessionResultEntry] {
        var comps = URLComponents(string: "\(openF1BaseURL)/session_result")!
        comps.queryItems = [
            .init(name: "session_key", value: String(sessionKey))
        ]
        let url = comps.url!
        print("🌐 session_result URL:", url.absoluteString)

        let arr: [SessionResultEntry] = try await fetchDecodable(url)
        return arr.sorted { ($0.position ?? 9_999) < ($1.position ?? 9_999) }
    }

    private func fetchSessionDrivers(sessionKey: Int) async throws -> [DriverInfo] {
        var comps = URLComponents(string: "\(openF1BaseURL)/drivers")!
        comps.queryItems = [
            .init(name: "session_key", value: String(sessionKey))
        ]
        let url = comps.url!
        print("🌐 drivers URL:", url.absoluteString)

        let arr: [DriverInfo] = try await fetchDecodable(url)
        return arr
    }

    // MARK: - Orchestrator

    private func fetchResults() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard
                    let year = Int(race.date.prefix(4)),
                    let circuitId = race.circuit_id,
                    let circuitKey = Int(circuitId)
                else {
                    throw NSError(domain: "OpenF1", code: -10,
                                  userInfo: [NSLocalizedDescriptionKey: "Lipsesc year sau circuit_key numeric pentru cursa selectată"])
                }

                // 1) meeting_key
                let mk = try await fetchMeetingKey(year: year, circuitKey: circuitKey)
                try? await Task.sleep(nanoseconds: 300_000_000) // light backoff
                // 2) session_key (Race, ultimul după date_start)
                let sk = try await fetchRaceSessionKey(meetingKey: mk)
                try? await Task.sleep(nanoseconds: 300_000_000)
                // 3) detalii piloți pentru nume
                let drivers = try await fetchSessionDrivers(sessionKey: sk)
                try? await Task.sleep(nanoseconds: 300_000_000)
                // 4) rezultate după session_key
                let res = try await fetchSessionResults(sessionKey: sk)

                await MainActor.run {
                    self.viewModel.drivers = drivers
                    self.results = res
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func driverName(for number: Int?) -> String {
        guard let num = number,
              let driver = viewModel.drivers.first(where: { $0.driver_number == num }) else { return "-" }
        return driver.full_name
    }

    private func gapText(for gap: GapToLeader?) -> String {
        guard let gap = gap else { return "-" }
        switch gap {
        case .seconds(let value):
            return value == 0 ? "Leader" : String(format: "+%.3f", value)
        case .laps(let laps):
            return laps
        }
    }
}

struct PodiumView: View {
    let entries: [SessionResultEntry]
    @ObservedObject var viewModel: HistoricalRaceViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ForEach(entries) { entry in
                VStack {
                    Text(driverName(for: entry.driver_number))
                        .font(.caption)
                    if entry.dnf == true {
                        Text("DNF")
                            .foregroundColor(.red)
                            .font(.caption2)
                    } else {
                        Text(gapText(for: entry.gap_to_leader))
                            .foregroundColor(.secondary)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    Text("\(entry.position ?? 0)")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func driverName(for number: Int?) -> String {
        guard let num = number,
              let driver = viewModel.drivers.first(where: { $0.driver_number == num }) else { return "-" }
        return driver.full_name
    }

    private func gapText(for gap: GapToLeader?) -> String {
        guard let gap = gap else { return "-" }
        switch gap {
        case .seconds(let value):
            return value == 0 ? "Leader" : String(format: "+%.3f", value)
        case .laps(let laps):
            return laps
        }
    }
}

