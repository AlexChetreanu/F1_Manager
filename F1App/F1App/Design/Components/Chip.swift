import SwiftUI

struct Chip: View {
    var text: String
    var systemImage: String?
    var body: some View {
        HStack(spacing: Layout.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, Layout.Spacing.m)
        .padding(.vertical, Layout.Spacing.xs)
        .background(AppColors.surface)
        .clipShape(Capsule())
    }
}

#Preview {
    Chip(text: "Finalizată", systemImage: "checkmark")
        .padding()
        .background(AppColors.bg)
}
