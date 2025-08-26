import SwiftUI

struct TeamChip: View {
    @EnvironmentObject var colorStore: TeamColorStore
    let teamId: Int?
    let teamName: String

    var body: some View {
        Text(teamName)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorStore.color(forTeamId: teamId))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}
