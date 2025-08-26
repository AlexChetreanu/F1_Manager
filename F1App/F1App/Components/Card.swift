import SwiftUI

struct Card<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding()
            .background(AppColors.surface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.stroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
