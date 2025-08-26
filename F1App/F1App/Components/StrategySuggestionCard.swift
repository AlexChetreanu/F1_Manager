import SwiftUI

struct StrategySuggestionCard: View {
    @Environment(\.colorScheme) private var scheme          // ← adaugă asta
    @EnvironmentObject var colorStore: TeamColorStore
    let suggestion: StrategySuggestion

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                DriverRow(
                    position: suggestion.position,
                    driverNumber: suggestion.driver_number,
                    driverName: suggestion.driver_name ?? "Driver \(suggestion.driver_number ?? 0)",
                    teamName: suggestion.team ?? "",
                    trend: nil
                )
                Text(suggestion.advice)
                    .titleL()
                    .foregroundColor(AppColors.textPrimary(scheme))   // ← apelează cu scheme

                Text(suggestion.why)
                    .bodyStyle()
                    .foregroundColor(AppColors.textSecondary(scheme)) // ← apelează cu scheme
            }
        }
        .animation(.interpolatingSpring(stiffness: 220, damping: 28), value: suggestion.id)
    }
}
