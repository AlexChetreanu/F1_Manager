import SwiftUI

struct DriverRow: View {
    @EnvironmentObject var colorStore: TeamColorStore
    @State private var appear = false

    let position: Int?
    let driverNumber: Int?
    let driverName: String
    let teamName: String
    let trend: Int?

    var body: some View {
        HStack(spacing: Layout.Spacing.m) {
            if let position {
                Text("\(position)")
                    .captionStyle()
                    .foregroundStyle(AppColors.textSec)
                    .frame(width: 24, alignment: .trailing)
            }

            Circle()
                .fill(colorStore.color(forTeamName: teamName))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(driverNumber.map(String.init) ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textPri)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(driverName)
                    .bodyStyle()
                    .foregroundStyle(AppColors.textPri)
                Text(teamName)
                    .captionStyle()
                    .foregroundStyle(AppColors.textSec)
            }

            Spacer()

            if let trend {
                Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                    .foregroundStyle(trend >= 0 ? Color.green : Color.red)
            }
        }
        .padding(.vertical, Layout.Spacing.xs)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 6)
        .onAppear {
            withAnimation(Motion.spring) {
                appear = true
            }
        }
    }
}
