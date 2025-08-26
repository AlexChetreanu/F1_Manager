import Foundation

struct TeamColor: Codable {
    let id: Int
    let name: String
    let primary: String
    let secondary: String?
}

struct TeamColorsResponse: Codable {
    let teams: [TeamColor]
}

final class TeamColorService {
    func fetchColors() async throws -> [TeamColor] {
        let url = API.url("/api/teams/colors")
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(TeamColorsResponse.self, from: data)
        return decoded.teams
    }
}
