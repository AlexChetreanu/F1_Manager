import SwiftUI

struct AppColors {
    static let background = Color { scheme in
        scheme == .dark ? Color(hex: "#0A0A0A") : Color(hex: "#FFFFFF")
    }
    static let surface = Color { scheme in
        scheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#F5F5F5")
    }
    static let textPrimary = Color { scheme in
        scheme == .dark ? Color(hex: "#FFFFFF") : Color(hex: "#0A0A0A")
    }
    static let textSecondary = Color { scheme in
        scheme == .dark ? Color(hex: "#CCCCCC") : Color(hex: "#555555")
    }
    static let accentRed = Color(hex: "#E10600")
    static let stroke = Color { scheme in
        scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
}
