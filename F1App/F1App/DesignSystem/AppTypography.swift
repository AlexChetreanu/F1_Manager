import SwiftUI

private struct TitleXL: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 28, weight: .bold))
            .dynamicTypeSize(.medium ... .accessibility2)
            .minimumScaleFactor(0.8)
    }
}

private struct TitleL: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 22, weight: .semibold))
            .dynamicTypeSize(.medium ... .accessibility2)
            .minimumScaleFactor(0.8)
    }
}

private struct BodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .dynamicTypeSize(.medium ... .accessibility2)
    }
}

private struct CaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .dynamicTypeSize(.medium ... .accessibility2)
            .minimumScaleFactor(0.8)
    }
}

extension View {
    func titleXL() -> some View { modifier(TitleXL()) }
    func titleL() -> some View { modifier(TitleL()) }
    func bodyStyle() -> some View { modifier(BodyStyle()) }
    func captionStyle() -> some View { modifier(CaptionStyle()) }
}
