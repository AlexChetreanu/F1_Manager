import SwiftUI

struct VectorSplashView: View {
    var onFinish: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Logo vectorial (fără imagini)
            F1VectorLogo()
                .scaleEffect(appear ? 1.0 : 0.85)
                .opacity(appear ? 1.0 : 0.0)
                .animation(
                    appear ? .easeOut(duration: 0.45)
                           : .easeInOut(duration: 0.8),
                    value: appear
                )
        }
        .onAppear {
            appear = true
            // Păstrează splash-ul ~3s, apoi estompează-l lent
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                appear = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onFinish()
                }
            }
        }
    }
}
