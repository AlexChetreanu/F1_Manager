import SwiftUI

struct TeamChip: View {
    @EnvironmentObject var colorStore: TeamColorStore
    @State private var pressed = false

    let teamId: Int?
    let teamName: String

    var body: some View {
        Text(teamName)
            .captionStyle()
            .padding(.horizontal, Layout.Spacing.l)
            .padding(.vertical, Layout.Spacing.s)
            .background(colorStore.color(forTeamId: teamId))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .scaleEffect(pressed ? 0.95 : 1)
            .animation(Motion.spring, value: pressed)
            .onTapGesture {
                pressed = true
                Haptics.soft()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    pressed = false
                }
            }
    }
}
