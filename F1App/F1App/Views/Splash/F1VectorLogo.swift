import SwiftUI

struct F1VectorLogo: View {
    var body: some View {
        F1MarkShape()
            .fill(Color.red)
            .drawingGroup() // rasterizare pt. anti-alias
            .aspectRatio(260/54.0, contentMode: .fit)
            .frame(width: 240) // se poate ajusta
            .accessibilityLabel("F1 style mark")
    }
}
