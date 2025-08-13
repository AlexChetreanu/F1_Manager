import Foundation

class HistoricRaceViewModel: ObservableObject {
    @Published var race: HistoricRace?

    func fetchRace(circuitId: String, year: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/meetings?year=\(year)&circuit_short_name=\(circuitId)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil, let data = data else {
                DispatchQueue.main.async { self.race = nil }
                if let error = error { print("Error fetching historic race:", error) }
                return
            }

            if let decoded = try? JSONDecoder().decode([HistoricRace].self, from: data) {
                let race = decoded.first { $0.meeting_name.contains("Grand Prix") }
                DispatchQueue.main.async { self.race = race }
            } else {
                DispatchQueue.main.async { self.race = nil }
            }
        }.resume()
    }
}
