import SwiftUI

struct MeetingEntry: Decodable {
    let meeting_key: Int
}

struct SessionEntry: Decodable {
    let session_key: Int
    let session_name: String?
    let date_start: String?
}

struct SessionResultEntry: Identifiable, Decodable {
    let position: Int?
    let driver_number: Int?
    let session_key: Int?
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
                Text("Se încarcă rezultatele…")
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
                        driverImage(for: entry.driver_number)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        Text(driverName(for: entry.driver_number))
                        Spacer()
                    }
                }
            }
        }
        .onAppear { if results.isEmpty { fetchResults() } }
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
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let head = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            print("⛔️ Decode failed for \(url): \(error)\nBody head: \(head)")
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
        var comps = URLComponents(string: "\(openF1BaseURL)/sessions")!
        comps.queryItems = [
            .init(name: "meeting_key", value: String(meetingKey)),
            .init(name: "order_by", value: "date_start")
        ]
        let url = comps.url!
        print("🌐 sessions URL:", url.absoluteString)

        let sessions: [SessionEntry] = try await fetchDecodable(url)

        // 1) ultima cu nume ce sugerează cursa
        if let sk = sessions.last(where: { ($0.session_name ?? "").localizedCaseInsensitiveContains("race")
                                       || ($0.session_name ?? "").localizedCaseInsensitiveContains("grand prix") })?.session_key {
            return sk
        }
        // 2) fallback: ultima sesiune
        if let sk = sessions.last?.session_key { return sk }

        throw NSError(domain: "OpenF1", code: -2,
                      userInfo: [NSLocalizedDescriptionKey: "Nu am găsit nicio sesiune pentru meeting_key \(meetingKey)"])
    }

    private func fetchSessionResults(sessionKey: Int) async throws -> [SessionResultEntry] {
        var comps = URLComponents(string: "\(openF1BaseURL)/session_result")!
        comps.queryItems = [
            .init(name: "session_key", value: String(sessionKey)),
            .init(name: "order_by", value: "position")
        ]
        let url = comps.url!
        print("🌐 session_result URL:", url.absoluteString)

        let arr: [SessionResultEntry] = try await fetchDecodable(url)
        return arr.sorted { ($0.position ?? 9_999) < ($1.position ?? 9_999) }
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
                // 2) session_key (Race, ultimul după date_start)
                try? await Task.sleep(nanoseconds: 400_000_000)
                let sk = try await fetchRaceSessionKey(meetingKey: mk)
                // 3) rezultate după session_key
                try? await Task.sleep(nanoseconds: 400_000_000)
                let res = try await fetchSessionResults(sessionKey: sk)

                await MainActor.run {
                    self.results = res
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Nu s-au putut încărca rezultatele: \(error.localizedDescription)"
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

    private func driverImage(for number: Int?) -> Image {
        guard let num = number,
              let driver = viewModel.drivers.first(where: { $0.driver_number == num }) else { return Image(systemName: "person.circle") }
        if let last = driver.full_name.split(separator: " ").last {
            return Image.driver(named: String(last))
        }
        return Image(systemName: "person.circle")
    }
}

struct PodiumView: View {
    let entries: [SessionResultEntry]
    @ObservedObject var viewModel: HistoricalRaceViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ForEach(entries) { entry in
                VStack {
                    driverImage(for: entry.driver_number)
                        .resizable()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    Text(driverName(for: entry.driver_number))
                        .font(.caption)
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

    private func driverImage(for number: Int?) -> Image {
        guard let num = number,
              let driver = viewModel.drivers.first(where: { $0.driver_number == num }) else { return Image(systemName: "person.circle") }
        if let last = driver.full_name.split(separator: " ").last {
            return Image.driver(named: String(last))
        }
        return Image(systemName: "person.circle")
    }
}

