import Foundation

class HistoricRaceViewModel: ObservableObject {
    @Published var race: Race?

    func fetchRace(circuitId: String, year: Int) {
        guard let url = URL(string: "http://localhost:8000/api/races?year=\(year)&circuit_id=\(circuitId)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil, let data = data else {
                DispatchQueue.main.async { self.race = nil }
                if let error = error { print("Error fetching historic race:", error) }
                return
            }

            if let decoded = try? JSONDecoder().decode([Race].self, from: data),
               let race = decoded.first {
                DispatchQueue.main.async { self.race = race }
            } else {
                DispatchQueue.main.async { self.race = nil }
            }
        }.resume()
    }
}
