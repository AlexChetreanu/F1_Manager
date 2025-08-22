import SwiftUI

struct VectorSplashView: View {
    var onFinish: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Logo vectorial
            F1VectorLogo()
                .scaleEffect(appear ? 1.0 : 0.85)
                .opacity(appear ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.45), value: appear)
        }
        .onAppear {
            appear = true
            // Finalizează splash-ul după ~1.2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.25)) { onFinish() }
            }
        
        }
    }
}
