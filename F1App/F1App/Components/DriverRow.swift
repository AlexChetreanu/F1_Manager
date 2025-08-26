import SwiftUI

struct DriverRow: View {
    @EnvironmentObject var colorStore: TeamColorStore
    let position: Int?
    let driverNumber: Int?
    let driverName: String
    let teamName: String
    let trend: Int?

    var body: some View {
        HStack(spacing: 12) {
            if let position = position {
                Text("\(position)")
                    .frame(width: 24)
                    .foregroundColor(AppColors.textSecondary)
            }
            Circle()
                .fill(colorStore.color(forTeamName: teamName))
                .frame(width: 32, height: 32)
                .overlay(Text(driverNumber.map(String.init) ?? "").foregroundColor(.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(driverName)
                    .bodyStyle()
                    .foregroundColor(AppColors.textPrimary)
                Text(teamName)
                    .captionStyle()
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            if let trend = trend {
                Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                    .foregroundColor(trend >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}
