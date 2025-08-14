//
//  CircuitView.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

struct CircuitView: View {
    let coordinatesJSON: String?
    let drivers: [DriverInfo]
    let driverPositions: [Int: LocationPoint]

    init(coordinatesJSON: String?, drivers: [DriverInfo] = [], driverPositions: [Int: LocationPoint] = [:]) {
        self.coordinatesJSON = coordinatesJSON
        self.drivers = drivers
        self.driverPositions = driverPositions
    }

    // Parse track coordinates and compute bounds
    func parseTrack() -> ([CGPoint], CGRect) {
        guard
            let jsonString = coordinatesJSON,
            let data = jsonString.data(using: .utf8),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]],
            !arr.isEmpty
        else {
            return ([], .zero)
        }

        let xs = arr.map { $0[0] }
        let ys = arr.map { $0[1] }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 1
        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        let points = arr.map { point in
            let x = (point[0] - minX) / (maxX - minX)
            let y = 1 - (point[1] - minY) / (maxY - minY)
            return CGPoint(x: x, y: y)
        }

        return (points, bounds)
    }

    func locationTransform(trackBounds: CGRect) -> CGAffineTransform? {
        let locs = Array(driverPositions.values)
        guard !locs.isEmpty,
              trackBounds.width > 0, trackBounds.height > 0 else { return nil }

        let xs = locs.map { $0.x }
        let ys = locs.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max(),
              maxX - minX > 0, maxY - minY > 0 else { return nil }

        let locBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let trackCenter = CGPoint(x: trackBounds.midX, y: trackBounds.midY)
        let locCenter = CGPoint(x: locBounds.midX, y: locBounds.midY)
        let trackVector = CGPoint(x: trackBounds.maxX - trackBounds.minX,
                                  y: trackBounds.maxY - trackBounds.minY)
        let locVector = CGPoint(x: locBounds.maxX - locBounds.minX,
                                y: locBounds.maxY - locBounds.minY)
        let trackAngle = atan2(trackVector.y, trackVector.x)
        let locAngle = atan2(locVector.y, locVector.x)
        let rotation = trackAngle - locAngle
        let scaleX = trackBounds.width / locBounds.width
        let scaleY = trackBounds.height / locBounds.height
        let scale = (scaleX + scaleY) / 2

        var t = CGAffineTransform.identity
        t = t.translatedBy(x: -locCenter.x, y: -locCenter.y)
        t = t.rotated(by: rotation)
        t = t.scaledBy(x: scale, y: scale)
        t = t.translatedBy(x: trackCenter.x, y: trackCenter.y)
        return t
    }

    func point(for loc: LocationPoint, transform: CGAffineTransform, trackBounds: CGRect, size: CGSize) -> CGPoint {
        let transformed = CGPoint(x: loc.x, y: loc.y).applying(transform)
        let nx = (transformed.x - trackBounds.minX) / trackBounds.width
        let ny = 1 - (transformed.y - trackBounds.minY) / trackBounds.height
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }

    var body: some View {
        GeometryReader { geo in
            let (points, bounds) = parseTrack()
            let transform = locationTransform(trackBounds: bounds)

            if points.isEmpty {
                Text("No coordinates available").foregroundColor(.red)
            } else {
                ZStack {
                    Path { path in
                        let first = points[0]
                        path.move(to: CGPoint(x: first.x * geo.size.width, y: first.y * geo.size.height))
                        for point in points.dropFirst() {
                            path.addLine(to: CGPoint(x: point.x * geo.size.width, y: point.y * geo.size.height))
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.blue, lineWidth: 2)

                    if let transform = transform {
                        ForEach(drivers) { driver in
                            if let loc = driverPositions[driver.driver_number] {
                                let p = point(for: loc, transform: transform, trackBounds: bounds, size: geo.size)
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .position(p)
                                Text(driver.initials)
                                    .font(.caption2)
                                    .position(x: p.x, y: p.y - 10)
                            }
                        }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
