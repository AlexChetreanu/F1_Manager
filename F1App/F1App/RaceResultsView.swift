import SwiftUI

struct SessionResultEntry: Identifiable, Decodable {
    let position: Int?
    let driver_number: Int?
    var id: Int { driver_number ?? Int.random(in: 1000...9999) }
}

struct SessionResultResponse: Decodable {
    let data: [SessionResultEntry]
}

struct RaceResultsView: View {
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
        .onAppear {
            if results.isEmpty, let sk = viewModel.sessionKey {
                fetchResults(sessionKey: sk)
            }
        }
    }

    private func fetchResults(sessionKey: Int) {
        var comps = URLComponents(string: "\(API.base)/api/openf1/session_result")!
        comps.queryItems = [
            URLQueryItem(name: "session_key", value: String(sessionKey)),
            URLQueryItem(name: "order_by", value: "position")
        ]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(SessionResultResponse.self, from: data) else { return }
            DispatchQueue.main.async { self.results = response.data }
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

