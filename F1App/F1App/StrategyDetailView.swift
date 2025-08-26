import SwiftUI

struct StrategyDetailView: View {
    let suggestion: StrategySuggestion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(suggestion.driver_name ?? "Driver \(suggestion.driver_number ?? 0)")
                    .font(.title)
                if let team = suggestion.team {
                    Text("Team: \(team)")
                }
                if let position = suggestion.position {
                    Text("Position: \(position)")
                }
                Text("Advice: \(suggestion.advice)")
                    .bold()
                Text("Why: \(suggestion.why)")
            }
            .padding()
        }
        .navigationTitle("Strategie")
    }
}

#Preview {
    StrategyDetailView(suggestion: StrategySuggestion(driver_number: 1,
                                                     driver_name: "Example Driver",
                                                     team: "Example Team",
                                                     position: 1,
                                                     advice: "Pit now",
                                                     why: "Fresh tires needed"))
}
