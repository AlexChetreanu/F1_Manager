import SwiftUI

struct AppShimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.9), Color.white.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .mask(content)
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

extension View {
    @ViewBuilder
    func shimmer(_ active: Bool = true) -> some View {
        if active {
            self.modifier(AppShimmer())
        } else {
            self
        }
    }
}


private struct SelfModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}
