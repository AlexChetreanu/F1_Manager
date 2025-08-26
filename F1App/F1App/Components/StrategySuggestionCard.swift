import SwiftUI

struct StrategySuggestionCard: View {
    @EnvironmentObject var colorStore: TeamColorStore
    let suggestion: StrategySuggestion

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                DriverRow(position: suggestion.position,
                          driverNumber: suggestion.driver_number,
                          driverName: suggestion.driver_name ?? "Driver \(suggestion.driver_number ?? 0)",
                          teamName: suggestion.team ?? "",
                          trend: nil)
                Text(suggestion.advice)
                    .titleL()
                    .foregroundColor(AppColors.textPrimary)
                Text(suggestion.why)
                    .bodyStyle()
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .animation(.interpolatingSpring(stiffness: 220, damping: 28), value: suggestion.id)
    }
}
