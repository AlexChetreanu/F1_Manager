import SwiftUI

struct RaceScreen: View {
    var race: RaceDetailData
    @State private var selectedTab: Tab = .summary

    enum Tab: Int, CaseIterable {
        case summary, results, strategy, circuit, history

        var title: String {
            switch self {
            case .summary: return "Rezumat"
            case .results: return "Rezultate"
            case .strategy: return "Strategie"
            case .circuit: return "Circuit"
            case .history: return "Istoric"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Content for selected tab
                Group {
                    switch selectedTab {
                    case .summary:
                        SummaryTab(race: race)
                    case .results:
                        ResultsTab(results: race.results)
                    case .strategy:
                        StrategyTab(drivers: race.drivers)
                    case .circuit:
                        CircuitTab(race: race)
                    case .history:
                        HistoryTab(history: race.history)
                    }
                }
                .padding(.top, Layout.Spacing.xl)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: Layout.Spacing.m) {
                RaceSummaryHeader(race: race)
                Picker("Tab", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            .background(AppColors.bg)
        }
        .navigationTitle(race.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sample Data Models

struct RaceDetailData {
    var name: String
    var round: Int
    var date: Date
    var coordinates: String? = nil
    var p1: DriverResultData
    var p2: DriverResultData
    var p3: DriverResultData
    var fastestLap: (time: String, driver: String)
    var scCount: Int
    var vscCount: Int
    var pitDelta: String
    var weatherIcon: String
    var weatherTemp: String
    var results: [DriverResultData]
    var drivers: [DriverStrategyData]
    var history: [PastRaceData]
    var trackFacts: [TrackFactData]
}

struct DriverResultData: Identifiable {
    let id = UUID()
    var name: String
    var team: String
    var points: Int = 0
    var gapToLeader: String? = nil
    var lastCompound: String? = nil
    var dnf: Bool = false
}

struct DriverStrategyData: Identifiable {
    let id = UUID()
    var name: String
    var team: String
    var stints: [StintData]
}

struct StintData: Identifiable {
    let id = UUID()
    var startLap: Int
    var endLap: Int
    var compound: String
}

struct PastRaceData: Identifiable {
    let id = UUID()
    var year: String
    var winner: String
    var poleToWin: String
    var pits: String
    var scRate: String
}

struct TrackFactData: Identifiable {
    let id = UUID()
    var label: String
    var value: String
}

extension RaceDetailData {
    static let sample: RaceDetailData = {
        let p1 = DriverResultData(name: "Max Verstappen", team: "Red Bull")
        let p2 = DriverResultData(name: "Sergio Perez", team: "Red Bull")
        let p3 = DriverResultData(name: "Charles Leclerc", team: "Ferrari")
        let results = [
            DriverResultData(name: "Max Verstappen", team: "Red Bull", points: 25, gapToLeader: "Leader", lastCompound: "S"),
            DriverResultData(name: "Sergio Perez", team: "Red Bull", points: 18, gapToLeader: "+5.0s", lastCompound: "S"),
            DriverResultData(name: "Charles Leclerc", team: "Ferrari", points: 15, gapToLeader: "+10.2s", lastCompound: "M")
        ]
        let drivers = [
            DriverStrategyData(name: "Max Verstappen", team: "Red Bull", stints: [
                StintData(startLap: 1, endLap: 20, compound: "S"),
                StintData(startLap: 21, endLap: 40, compound: "M")
            ])
        ]
        let history = [
            PastRaceData(year: "2023", winner: "Max Verstappen", poleToWin: "80%", pits: "1-2", scRate: "40%"),
            PastRaceData(year: "2022", winner: "Charles Leclerc", poleToWin: "60%", pits: "2", scRate: "30%"),
            PastRaceData(year: "2021", winner: "Lewis Hamilton", poleToWin: "70%", pits: "2", scRate: "50%")
        ]
        let facts = [
            TrackFactData(label: "Lungime", value: "5.9 km"),
            TrackFactData(label: "Ture", value: "58"),
            TrackFactData(label: "Viraje", value: "16"),
            TrackFactData(label: "Lap record", value: "1:21.046"),
            TrackFactData(label: "Pierdere pit", value: "23s"),
            TrackFactData(label: "Prob. SC", value: "40%")
        ]
        return RaceDetailData(
            name: "Imola", round: 6, date: Date(),
            coordinates: nil,
            p1: p1, p2: p2, p3: p3,
            fastestLap: ("1:23.456", "Max Verstappen"),
            scCount: 1, vscCount: 1, pitDelta: "23.1s",
            weatherIcon: "sun.max", weatherTemp: "24°C",
            results: results, drivers: drivers, history: history, trackFacts: facts
        )
    }()
}

struct PreviewColorService: TeamColorProviding {
    func fetchColors() async throws -> [TeamColor] {
        [TeamColor(id: 1, name: "Red Bull", primary: "#3671C6", secondary: nil),
         TeamColor(id: 2, name: "Ferrari", primary: "#E10600", secondary: nil)]
    }
}

#Preview {
    NavigationView {
        RaceScreen(race: .sample)
            .environmentObject(TeamColorStore(service: PreviewColorService()))
    }
}
