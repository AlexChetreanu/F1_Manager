import SwiftUI

struct VectorSplashView: View {
    var onFinish: () -> Void
    @State private var appear = false
    @State private var showLines = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Logo vectorial (fără imagini)
            F1VectorLogo()
                .scaleEffect(appear ? 1.0 : 0.85)
                .opacity(appear ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.45), value: appear)

            if showLines {
                // 3 linii care „vin din stânga”
                VStack(spacing: 8) {
                    speedLine(width: 160).offset(x: appear ? 0 : -240)
                    speedLine(width: 200).offset(x: appear ? 0 : -280)
                    speedLine(width: 240).offset(x: appear ? 0 : -320)
                }
                .frame(width: 260, height: 80, alignment: .trailing)
                .offset(y: 70)
                .animation(.easeOut(duration: 0.6), value: appear)
            }
        }
        .onAppear {
            showLines = true
            appear = true
            // Finalizează splash-ul după ~1.2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.25)) { onFinish() }
            }
        }
    }

    private func speedLine(width: CGFloat) -> some View {
        SpeedLineShape()
            .fill(Color.red.opacity(0.85))
            .frame(width: width, height: 8)
    }
}
