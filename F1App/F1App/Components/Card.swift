import SwiftUI

struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Layout.Spacing.l)
            .background(AppColors.surface)
            .cornerRadius(Layout.Radius.standard)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.Radius.standard)
                    .stroke(AppColors.stroke, lineWidth: 1)
            )
            .shadow(color: Layout.Shadow.color,
                    radius: Layout.Shadow.radius,
                    x: 0, y: Layout.Shadow.y)
    }
}
