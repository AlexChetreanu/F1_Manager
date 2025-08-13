import Foundation

class HistoricRaceViewModel: ObservableObject {
    @Published var race: Race?

    func fetchRace(circuitId: String, year: Int) {
        guard let url = URL(string: "http://localhost:8000/api/races?year=\(year)&circuit_id=\(circuitId)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let decoded = try? JSONDecoder().decode([Race].self, from: data) {
                    DispatchQueue.main.async {
                        self.race = decoded.first
                    }
                }
            } else if let error = error {
                print("Error fetching historic race:", error)
            }
        }.resume()
    }
}
