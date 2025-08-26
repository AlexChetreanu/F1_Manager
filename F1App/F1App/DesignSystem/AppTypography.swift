import SwiftUI

extension View {
    func titleXL() -> some View {
        self.font(.system(size: 28, weight: .bold, design: .default))
    }
    func titleL() -> some View {
        self.font(.system(size: 22, weight: .semibold, design: .default))
    }
    func bodyStyle() -> some View {
        self.font(.system(size: 16, weight: .regular, design: .default))
    }
    func captionStyle() -> some View {
        self.font(.system(size: 13, weight: .regular, design: .default))
    }
}
