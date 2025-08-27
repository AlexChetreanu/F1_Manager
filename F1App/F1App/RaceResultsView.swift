import SwiftUI

struct SessionResultEntry: Identifiable, Decodable {
    let position: Int?
    let driver_number: Int?
    let session_key: Int?
    var id: Int { driver_number ?? Int.random(in: 1000...9999) }
}

private struct MeetingEntry: Decodable { let meeting_key: Int }

struct RaceResultsView: View {
    let race: Race
    @ObservedObject var viewModel: HistoricalRaceViewModel
    @State private var results: [SessionResultEntry] = []

    var body: some View {
        VStack(spacing: 16) {
            if results.isEmpty {
                Text("Se încarcă rezultatele...")
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
        guard
            let circuitId = race.circuit_id,
            let circuitKey = Int(circuitId),
            let yearInt = Int(race.date.prefix(4))
        else { return }

        var meetingComps = URLComponents(string: "\(openF1BaseURL)/meetings")!
        meetingComps.queryItems = [
            URLQueryItem(name: "year", value: String(yearInt)),
            URLQueryItem(name: "circuit_key", value: String(circuitKey))
        ]
        guard let meetingURL = meetingComps.url else { return }

        URLSession.shared.dataTask(with: meetingURL) { data, _, _ in
            guard
                let data = data,
                let meetings = try? JSONDecoder().decode([MeetingEntry].self, from: data),
                let meetingKey = meetings.last?.meeting_key ?? meetings.first?.meeting_key
            else { return }

            var resultsComps = URLComponents(string: "\(openF1BaseURL)/session_result")!
            resultsComps.queryItems = [
                URLQueryItem(name: "meeting_key", value: String(meetingKey)),
                URLQueryItem(name: "order_by", value: "position"),
                URLQueryItem(name: "session_type", value: "Race")
            ]
            guard let resultsURL = resultsComps.url else { return }

            URLSession.shared.dataTask(with: resultsURL) { data, _, _ in
                guard
                    let data = data,
                    let response = try? JSONDecoder().decode([SessionResultEntry].self, from: data)
                else { return }

                DispatchQueue.main.async { self.results = response }
            }.resume()
        }.resume()
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

