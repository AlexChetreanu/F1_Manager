import SwiftUI

/// Conturul oficial al logo-ului Formula 1 redat vectorial.
/// Coordonatele sunt preluate din fișierul SVG public și normalizate
/// la o bază 120x30, apoi scalate pentru rectul disponibil.
struct F1LogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 120.0
        let sy = rect.height / 30.0

        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()

        // Cifra „1” din dreapta
        path.move(to: P(89.9999375, 30))
        path.addLine(to: P(119.999937, 0))
        path.addLine(to: P(101.943687, 0))
        path.addLine(to: P(71.9443125, 30))
        path.closeSubpath()

        // Aripa superioară a literei „F”
        path.move(to: P(85.6986875, 13.065))
        path.addLine(to: P(49.3818125, 13.065))
        path.addCurve(to: P(31.6361875, 18.3925),
                      control1: P(38.3136875, 13.065),
                      control2: P(36.3768125, 13.651875))
        path.addCurve(to: P(20.0005625, 30),
                      control1: P(27.2024375, 22.82625),
                      control2: P(20.0005625, 30))
        path.addLine(to: P(35.7324375, 30))
        path.addLine(to: P(39.4855625, 26.246875))
        path.addCurve(to: P(48.4068125, 23.52375),
                      control1: P(41.9530625, 23.779375),
                      control2: P(43.2255625, 23.52375))
        path.addLine(to: P(75.2405625, 23.52375))
        path.addLine(to: P(85.6986875, 13.065))
        path.closeSubpath()

        // Aripa inferioară a literei „F”
        path.move(to: P(31.1518125, 16.253125))
        path.addCurve(to: P(16.9130625, 30),
                      control1: P(27.8774375, 19.3425),
                      control2: P(20.7530625, 26.263125))
        path.addLine(to: P(0, 30))
        path.addCurve(to: P(21.0849375, 9.0725),
                      control1: P(0, 30),
                      control2: P(13.5524375, 16.486875))
        path.addCurve(to: P(46.9486875, 0),
                      control1: P(28.8455625, 1.685),
                      control2: P(32.7143125, 0))
        path.addLine(to: P(98.7643125, 0))
        path.addLine(to: P(87.5449375, 11.21875))
        path.addLine(to: P(48.0011875, 11.21875))
        path.addCurve(to: P(31.1518125, 16.253125),
                      control1: P(37.9993125, 11.21875),
                      control2: P(35.7518125, 11.911875))
        path.closeSubpath()

        return path
    }
}
