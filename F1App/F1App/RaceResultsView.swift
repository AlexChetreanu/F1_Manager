import SwiftUI

struct SessionResultEntry: Identifiable, Decodable {
    let position: Int?
    let driver_number: Int?
    let meeting_key: Int?
    let session_key: Int?
    let duration: Double?
    let number_of_laps: Int?
    let dnf: Bool?
    let dns: Bool?
    let dsq: Bool?
    var id: Int { (driver_number ?? Int.random(in: 1000...9999)) ^ (session_key ?? 0) }
}

private struct MeetingEntry: Decodable { let meeting_key: Int }

struct RaceResultsView: View {
    let race: Race
    @ObservedObject var viewModel: HistoricalRaceViewModel
    @State private var results: [SessionResultEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                Text("Se încarcă rezultatele...")
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

    private func fetchResults() {
        isLoading = true
        errorMessage = nil
        guard let circuitId = race.circuit_id, let circuitKey = Int(circuitId) else {
            errorMessage = "Lipsă circuit_key valid pentru căutarea meeting-ului."
            isLoading = false
            return
        }
        guard let yearInt = Int(race.date.prefix(4)) else {
            errorMessage = "Dată invalidă pentru cursă."
            isLoading = false
            return
        }

        Task {
            do {
                let meetingKey = try await fetchMeetingKey(year: yearInt, circuitKey: circuitKey)
                let allResults = try await fetchSessionResults(meetingKey: meetingKey)
                let grouped = Dictionary(grouping: allResults, by: { $0.session_key ?? -1 })
                let chosen = chooseRaceGroup(from: grouped)
                let sorted = chosen.sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
                await MainActor.run {
                    self.results = sorted
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

    private func fetchMeetingKey(year: Int, circuitKey: Int) async throws -> Int {
        var meetingComps = URLComponents(string: "\(openF1BaseURL)/meetings")!
        meetingComps.queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "circuit_key", value: String(circuitKey))
        ]
        guard let meetingURL = meetingComps.url else { throw URLError(.badURL) }
        print("🌐 meetings URL:", meetingURL.absoluteString)
        let (data, _) = try await URLSession.shared.data(from: meetingURL)
        let meetings = try JSONDecoder().decode([MeetingEntry].self, from: data)
        guard let meetingKey = meetings.last?.meeting_key ?? meetings.first?.meeting_key else {
            throw URLError(.badServerResponse)
        }
        return meetingKey
    }

    private func fetchSessionResults(meetingKey: Int) async throws -> [SessionResultEntry] {
        var resultsComps = URLComponents(string: "\(openF1BaseURL)/session_result")!
        resultsComps.queryItems = [
            URLQueryItem(name: "meeting_key", value: String(meetingKey))
        ]
        guard let resultsURL = resultsComps.url else { throw URLError(.badURL) }
        print("🌐 session_result URL:", resultsURL.absoluteString)
        let (data, _) = try await URLSession.shared.data(from: resultsURL)
        return try JSONDecoder().decode([SessionResultEntry].self, from: data)
    }

    private func chooseRaceGroup(from grouped: [Int: [SessionResultEntry]]) -> [SessionResultEntry] {
        if let byDuration = grouped.max(by: { a, b in
            (a.value.compactMap { $0.duration }.max() ?? 0) <
            (b.value.compactMap { $0.duration }.max() ?? 0)
        }), (byDuration.value.compactMap { $0.duration }.max() ?? 0) > 0 {
            return byDuration.value
        }
        return grouped.max(by: { a, b in
            let lapsA = a.value.compactMap { $0.number_of_laps }.reduce(0, +)
            let lapsB = b.value.compactMap { $0.number_of_laps }.reduce(0, +)
            return lapsA < lapsB
        })?.value ?? []
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
