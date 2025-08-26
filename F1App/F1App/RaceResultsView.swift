import SwiftUI

struct RaceResultsView: View {
    let race: Race
    @StateObject private var viewModel = RaceResultsViewModel()

    var body: some View {
        List(viewModel.results) { result in
            HStack {
                Text(result.position)
                    .frame(width: 30, alignment: .leading)
                AsyncImage(url: result.imageURL) { image in
                    image
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading) {
                    Text(result.driverName)
                    Text("\(result.points) pct")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task { await viewModel.loadResults(for: race) }
    }
}

struct RaceResultItem: Identifiable {
    let id = UUID()
    let position: String
    let driverName: String
    let points: String
    let driverId: String

    var imageURL: URL? {
        let slug = driverId.replacingOccurrences(of: "_", with: "-")
        return URL(string: "https://media.formula1.com/content/dam/fom-website/drivers/2024Drivers/\(slug).png")
    }
}

class RaceResultsViewModel: ObservableObject {
    @Published var results: [RaceResultItem] = []

    func loadResults(for race: Race) async {
        guard let url = URL(string: "https://ergast.com/api/f1/2025/\(race.id)/results.json") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ErgastResponse.self, from: data)
            let items = decoded.MRData.RaceTable.Races.first?.Results ?? []
            await MainActor.run {
                self.results = items.map {
                    RaceResultItem(position: $0.position,
                                   driverName: "\($0.Driver.givenName) \($0.Driver.familyName)",
                                   points: $0.points,
                                   driverId: $0.Driver.driverId)
                }
            }
        } catch {
            // Ignoră erorile de rețea
        }
    }
}

struct ErgastResponse: Decodable {
    let MRData: MRData

    struct MRData: Decodable {
        let RaceTable: RaceTable
    }

    struct RaceTable: Decodable {
        let Races: [Race]
    }

    struct Race: Decodable {
        let Results: [Result]
    }

    struct Result: Decodable {
        let position: String
        let points: String
        let Driver: Driver
    }

    struct Driver: Decodable {
        let driverId: String
        let givenName: String
        let familyName: String
    }
}

