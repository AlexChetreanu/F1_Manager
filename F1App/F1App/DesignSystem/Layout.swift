import SwiftUI

enum Layout {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let standard: CGFloat = 20
        static let chip: CGFloat = 12
    }

    enum Shadow {
        static let color = Color.black.opacity(0.05)
        static let radius: CGFloat = 4
        static let y: CGFloat = 2
    }
}
