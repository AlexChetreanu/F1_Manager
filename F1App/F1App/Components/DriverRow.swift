import SwiftUI

struct DriverRow: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var colorStore: TeamColorStore

    let position: Int?
    let driverNumber: Int?
    let driverName: String
    let teamName: String
    let trend: Int?

    var body: some View {
        HStack(spacing: 12) {
            if let position {
                Text("\(position)")
                    .frame(width: 24, alignment: .trailing)
                    .foregroundColor(AppColors.textSecondary(scheme))
            }

            Circle()
                .fill(colorStore.color(forTeamName: teamName))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(driverNumber.map(String.init) ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(driverName)
                    .bodyStyle()
                    .foregroundColor(AppColors.textPrimary(scheme))

                Text(teamName)
                    .captionStyle()
                    .foregroundColor(AppColors.textSecondary(scheme))
            }

            Spacer()

            if let trend {
                Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                    .foregroundColor(trend >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}
