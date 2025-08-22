import SwiftUI

/// Marcă stilizată F1 (nu logo oficial), desenată din poligoane.
/// Coordonatele sunt normalizate după o bază 260x54 și scalate la rect.
struct F1MarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 260.0
        let sy = rect.height / 54.0

        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()

        // „F” stilizat
        path.move(to: P(0, 0))
        path.addLine(to: P(140, 0))
        path.addLine(to: P(140, 18))
        path.addLine(to: P(40, 18))
        path.addLine(to: P(40, 36))
        path.addLine(to: P(110, 36))
        path.addLine(to: P(110, 54))
        path.addLine(to: P(0, 54))
        path.closeSubpath()

        // Cifra „1” simplă
        path.move(to: P(170, 0))
        path.addLine(to: P(260, 0))
        path.addLine(to: P(240, 20))
        path.addLine(to: P(210, 20))
        path.addLine(to: P(210, 54))
        path.addLine(to: P(170, 54))
        path.closeSubpath()

        return path
    }
}

/// Linii de viteză simple (pentru efect vizual)
struct SpeedLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: rect.height/2)
        return p
    }
}
