import SwiftUI

struct SummaryTab: View {
    var race: RaceDetailData

    var body: some View {
        VStack(spacing: Layout.Spacing.l) {
            CardView(title: "Momente cheie") {
                Text("SC la turul 23, pit decisiv P2")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            CardView(title: "Pace & gaps") {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.stroke)
                    .frame(height: 80)
            }
            CardView(title: "Anvelope folosite") {
                HStack(spacing: Layout.Spacing.s) {
                    Capsule().fill(Color.red).frame(width: 80, height: 20)
                    Capsule().fill(Color.yellow).frame(width: 60, height: 20)
                    Capsule().fill(Color.gray).frame(width: 40, height: 20)
                }
            }
            CardView(title: "Evoluția pozițiilor") {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.stroke, lineWidth: 2)
                    .frame(height: 120)
            }
        }
        .padding()
    }
}

struct CardView<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.m) {
            Text(title)
                .font(.title2)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SummaryTab(race: .sample)
        .background(AppColors.bg)
}
