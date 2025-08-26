import SwiftUI

struct StrategyDetailView: View {
    let suggestion: StrategySuggestion
    let driver: DriverInfo?

    var body: some View {
        ScrollView {
            Card {
                VStack(alignment: .leading, spacing: Layout.Spacing.m) {
                    DriverRow(
                        position: suggestion.position,
                        driverNumber: suggestion.driver_number,
                        driverName: driver?.full_name ?? (suggestion.driver_name ?? "Driver \(suggestion.driver_number ?? 0)"),
                        teamName: driver?.team_name ?? (suggestion.team ?? ""),
                        trend: nil,
                        teamColor: driver?.team_color.map(Color.init(hex:))
                    )

                    Text("Advice")
                        .titleL()
                        .foregroundStyle(AppColors.textPri)
                    Text(suggestion.advice)
                        .bodyStyle()
                        .foregroundStyle(AppColors.textSec)

                    Text("Why")
                        .titleL()
                        .foregroundStyle(AppColors.textPri)
                    Text(suggestion.why)
                        .bodyStyle()
                        .foregroundStyle(AppColors.textSec)
                }
            }
            .padding(Layout.Spacing.l)
        }
        .background(AppColors.bg.ignoresSafeArea())
        .navigationTitle("Strategie")
    }
}

#Preview {
    StrategyDetailView(
        suggestion: StrategySuggestion(driver_number: 1,
                                      driver_name: "Example Driver",
                                      team: "Example Team",
                                      position: 1,
                                      advice: "Pit now",
                                      why: "Fresh tires needed"),
        driver: DriverInfo(driver_number: 1,
                           full_name: "Example Driver",
                           team_color: "FF0000",
                           team_name: "Example Team")
    )
}
