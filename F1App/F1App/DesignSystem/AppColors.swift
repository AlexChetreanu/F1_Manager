import SwiftUI

enum AppColors {
    private static func dynamicColor(dark: UIColor, light: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let bg = dynamicColor(
        dark: UIColor(red: 0.039, green: 0.039, blue: 0.039, alpha: 1),
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    )

    static let surface = dynamicColor(
        dark: UIColor(red: 0.066, green: 0.071, blue: 0.082, alpha: 1),
        light: UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    )

    static let textPri = dynamicColor(
        dark: UIColor(red: 1, green: 1, blue: 1, alpha: 1),
        light: UIColor(red: 0.039, green: 0.039, blue: 0.039, alpha: 1)
    )

    static let textSec = dynamicColor(
        dark: UIColor(red: 0.654, green: 0.671, blue: 0.701, alpha: 1),
        light: UIColor(red: 0.290, green: 0.290, blue: 0.290, alpha: 1)
    )

    static let accent = Color(red: 0.882, green: 0.024, blue: 0)

    static let stroke = dynamicColor(
        dark: UIColor(white: 1, alpha: 0.10),
        light: UIColor(white: 0, alpha: 0.08)
    )
}
