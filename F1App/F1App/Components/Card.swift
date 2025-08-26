import SwiftUI

struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme   // ← adăugat

    private let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(AppColors.surface(scheme))   // ← apelează cu scheme
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.stroke(scheme), lineWidth: 1)  // ← apelează cu scheme
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
