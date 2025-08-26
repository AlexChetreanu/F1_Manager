import SwiftUI

struct StrategySuggestionCard: View {
    @EnvironmentObject var colorStore: TeamColorStore
    let suggestion: StrategySuggestion

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Layout.Spacing.m) {
                DriverRow(
                    position: suggestion.position,
                    driverNumber: suggestion.driver_number,
                    driverName: suggestion.driver_name ?? "Driver \(suggestion.driver_number ?? 0)",
                    teamName: suggestion.team ?? "",
                    trend: nil
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
