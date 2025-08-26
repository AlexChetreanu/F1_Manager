import SwiftUI

@MainActor
final class TeamColorStore: ObservableObject {
    @Published private(set) var colorsByTeamId: [Int: Color] = [:]
    @Published private(set) var colorsByTeamName: [String: Color] = [:]

    private let service: TeamColorProviding
    private let cacheKey = "team_colors_cache"

    init(service: TeamColorProviding = TeamColorService()) {
        self.service = service
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([TeamColor].self, from: data) {
            apply(decoded)
        }
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let fetched = try await service.fetchColors()
            apply(fetched)
            if let data = try? JSONEncoder().encode(fetched) {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
        } catch {
            // ignore
        }
    }

    private func apply(_ list: [TeamColor]) {
        var byId: [Int: Color] = [:]
        var byName: [String: Color] = [:]
        for item in list {
            let color = Color(hex: item.primary)
            byId[item.id] = color
            byName[item.name.lowercased()] = color
        }
        colorsByTeamId = byId
        colorsByTeamName = byName
    }

    func color(forTeamId id: Int?) -> Color {
        guard let id, let color = colorsByTeamId[id] else { return AppColors.accent }
        return color
    }

    func color(forTeamName name: String?) -> Color {
        guard let name, let color = colorsByTeamName[name.lowercased()] else { return AppColors.accent }
        return color
    }
}
