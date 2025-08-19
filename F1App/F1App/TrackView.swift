import SwiftUI

/// Draws driver markers on top of a static circuit map using the
/// bounds provided by the backend. Guards against zero-sized layouts
/// and uses small opacity transitions to avoid flicker.
struct TrackView: View {
    struct TrackInfo {
        struct Bounds { let minX: Double; let minY: Double; let maxX: Double; let maxY: Double }
        let imageURL: URL?
        let bounds: Bounds
    }
    struct DriverPos: Identifiable {
        let id: String
        let x: Double
        let y: Double
        let color: Color
    }

    let track: TrackInfo
    let drivers: [DriverPos]

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 0 && geo.size.height > 0 {
                ZStack {
                    if let url = track.imageURL {
                        AsyncImage(url: url) { img in
                            img.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.black.opacity(0.1)
                        }
                    }
                    ForEach(drivers) { d in
                        Circle()
                            .fill(d.color)
                            .frame(width: 10, height: 10)
                            .position(position(for: d, in: geo.size))
                            .transition(.opacity)
                            .animation(.linear(duration: 0.15), value: d.id)
                    }
                }
            } else {
                Color.clear
            }
        }
    }

    func position(for driver: DriverPos, in size: CGSize) -> CGPoint {
        let b = track.bounds
        let w = max(b.maxX - b.minX, 1)
        let h = max(b.maxY - b.minY, 1)
        let sx = size.width / w
        let sy = size.height / h
        let x = (driver.x - b.minX) * sx
        let y = size.height - (driver.y - b.minY) * sy
        return CGPoint(x: x.isFinite ? x : 0, y: y.isFinite ? y : 0)
    }
}
