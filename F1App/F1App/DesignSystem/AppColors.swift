import SwiftUI

struct AppColors {
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#0A0A0A") : Color(hex: "#FFFFFF")
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#1A1A1A") : Color(hex: "#F5F5F5")
    }
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#FFFFFF") : Color(hex: "#0A0A0A")
    }
    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#CCCCCC") : Color(hex: "#555555")
    }
    static let accentRed = Color(hex: "#E10600")
    static func stroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
}
