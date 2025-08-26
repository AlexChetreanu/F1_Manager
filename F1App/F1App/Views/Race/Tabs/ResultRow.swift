import SwiftUI

struct ResultRow: View {
    var position: Int
    var result: DriverResultData
    @EnvironmentObject var colorStore: TeamColorStore

    var body: some View {
        HStack(spacing: Layout.Spacing.m) {
            Text("\(position)")
                .frame(width: 28)
                .font(.headline)
            VStack(alignment: .leading) {
                Text(result.name)
                    .font(.headline)
                Text(result.dnf ? "DNF" : (result.gapToLeader ?? ""))
                    .font(.caption)
                    .foregroundStyle(result.dnf ? Color.red : AppColors.textSec)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(result.points)")
                    .font(.headline)
                if let compound = result.lastCompound {
                    Text(compound)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSec)
                }
            }
        }
        .padding(.vertical, Layout.Spacing.s)
        .padding(.leading, Layout.Spacing.m)
        .background(
            colorStore.color(forTeamName: result.team)
                .frame(width: 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
        .accessibilityLabel("Poziția \(position), \(result.name), \(result.points) puncte")
    }
}

#Preview {
    ResultRow(position: 1, result: RaceDetailData.sample.results[0])
        .environmentObject(TeamColorStore(service: PreviewColorService()))
        .padding()
}
