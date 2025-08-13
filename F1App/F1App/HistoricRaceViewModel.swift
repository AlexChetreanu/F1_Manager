import Foundation

class HistoricRaceViewModel: ObservableObject {
    @Published var race: Race?
    @Published var message: String?

    func fetchRace(circuitId: String, year: Int) {
        message = nil
        race = nil

        guard let url = URL(string: "https://api.openf1.org/v1/races?year=\(year)&circuit_id=\(circuitId)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil, let data = data else {
                DispatchQueue.main.async {
                    self.race = nil
                    self.message = "Nu s-a ținut cursa pe acest circuit în anul selectat."
                }
                if let error = error { print("Error fetching historic race:", error) }
                return
            }

            if let decoded = try? JSONDecoder().decode([Race].self, from: data),
               let race = decoded.first {
                DispatchQueue.main.async {
                    self.race = race
                    self.message = nil
                }
            } else {
                DispatchQueue.main.async {
                    self.race = nil
                    self.message = "Nu s-a ținut cursa pe acest circuit în anul selectat."
                }
            }
        }.resume()
    }
}
