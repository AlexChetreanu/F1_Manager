import SwiftUI

struct F1VectorLogo: View {
    var body: some View {
        F1LogoShape()
            .fill(Color.red)
            .drawingGroup() // rasterizare pentru anti-alias
            .aspectRatio(120/30.0, contentMode: .fit)
            .frame(width: 240)
            .accessibilityLabel("F1 logo")
    }
}
