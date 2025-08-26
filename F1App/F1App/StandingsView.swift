import SwiftUI

struct StandingsView: View {
    @State private var standings: [DriverStanding] = []
    @State private var selectedTab: String = "Piloți"
    
    var body: some View {
        NavigationView {
            VStack (spacing: 0){
                Picker("Clasament", selection: $selectedTab) {
                    Text("Piloți").tag("Piloți")
                    Text("Echipe").tag("Echipe")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                //.frame(height: 30)
                .font(.subheadline)
                
                List {
                    if selectedTab == "Piloți" {
                        ForEach(standings.sorted(by: { $0.points > $1.points }), id: \.id) { standing in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading) {
                                    Text(standing.name)
                                        .font(.headline)
                                    Text(standing.team)
                                        .font(.subheadline)
                                    Text("Puncte: \(standing.points)")
                                        .font(.subheadline)
                                }
                                Spacer()
                                Image.driver(named: standing.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40, alignment: .top)
                                    .scaleEffect(1.3, anchor: .top)
                                    .clipped()
                                    .clipShape(Circle())
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        ForEach(teamStandings(), id: \.team) { teamStanding in
                            VStack(alignment: .leading) {
                                Text(teamStanding.team)
                                    .font(.headline)
                                Text("Puncte: \(teamStanding.points)")
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .refreshable {
                    loadData()
                }
            }
            .navigationTitle("Clasament")
            .navigationBarTitleDisplayMode(.inline)

            
        }
        .onAppear(perform: loadData)
    }

    func loadData() {
        fetchStandings { result in
            if let result = result {
                self.standings = result
            }
        }
    }
    
    func teamStandings() -> [TeamStanding] {
        let grouped = Dictionary(grouping: standings, by: { $0.team })
        let teamStandings = grouped.map { (team, drivers) in
            TeamStanding(team: team, points: drivers.reduce(0) { $0 + $1.points })
        }
        return teamStandings.sorted { $0.points > $1.points }
    }
    
}

// Structură nouă pentru echipe
struct TeamStanding: Identifiable {
    let id = UUID()
    let team: String
    let points: Int
}
