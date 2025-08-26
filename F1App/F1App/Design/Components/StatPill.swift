import SwiftUI

struct StatPill: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        VStack(spacing: Layout.Spacing.s) {
            Image(systemName: icon)
                .font(.title2)
            VStack(spacing: Layout.Spacing.xs) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSec)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.m)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        StatPill(icon: "timer", title: "Fastest", value: "1:23.456")
        StatPill(icon: "flag.checkered", title: "Laps", value: "58")
    }
    .padding()
    .background(AppColors.bg)
}
