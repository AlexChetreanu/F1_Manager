import SwiftUI

@MainActor
final class TeamColorStore: ObservableObject {
    @Published private(set) var colors: [Int: TeamColor] = [:]
    private let service = TeamColorService()
    private let cacheKey = "team_colors_cache"

    init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([Int: TeamColor].self, from: data) {
            colors = decoded
        }
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let fetched = try await service.fetchColors()
            var dict: [Int: TeamColor] = [:]
            for c in fetched { dict[c.id] = c }
            colors = dict
            if let data = try? JSONEncoder().encode(dict) {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
        } catch {
            // ignore errors for now
        }
    }

    func color(forTeamId id: Int?) -> Color {
        guard let id = id, let hex = colors[id]?.primary else { return AppColors.accentRed }
        return Color(hex: hex)
    }

    func color(forTeamName name: String?) -> Color {
        guard let name = name else { return AppColors.accentRed }
        if let match = colors.values.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return Color(hex: match.primary)
        }
        return AppColors.accentRed
    }

    func color(forDriverNumber number: Int?) -> Color {
        // Driver to team mapping not available yet
        return AppColors.accentRed
    }
}
