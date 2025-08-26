import SwiftUI

struct StrategySuggestionCard: View {
    let suggestion: StrategySuggestion
    let driver: DriverInfo?

    var body: some View {
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

                Text(suggestion.advice)
                    .titleL()
                    .foregroundStyle(AppColors.textPri)

                Text(suggestion.why)
                    .bodyStyle()
                    .foregroundStyle(AppColors.textSec)
            }
        }
        .animation(Motion.spring, value: suggestion.id)
    }
}
