//
//  CircuitView.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

struct CircuitView: View {
    @ObservedObject var viewModel: HistoricalRaceViewModel

    var body: some View {
        GeometryReader { geo in
            let points = viewModel.trackPoints

            if points.isEmpty {
                Text("No coordinates available").foregroundColor(.red)
            } else {
                let driverPoints = viewModel.drivers.compactMap { driver -> (DriverInfo, CGPoint)? in
                    if let loc = viewModel.currentPosition[driver.driver_number] {
                        let p = viewModel.point(for: loc, in: geo.size)
                        return (driver, p)
                    }
                    return nil
                }
                let inBounds = driverPoints.filter { (_, p) in
                    p.x >= 0 && p.x <= geo.size.width && p.y >= 0 && p.y <= geo.size.height
                }
                let hasOutOfBounds = inBounds.count != driverPoints.count

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

                    ForEach(inBounds, id: \.0.id) { driver, p in
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .position(p)
                        Text(driver.initials)
                            .font(.caption2)
                            .position(x: p.x, y: p.y - 10)
                    }

                    if hasOutOfBounds {
                        Text("Puncte în afara circuitului")
                            .foregroundColor(.red)
                            .position(x: geo.size.width / 2, y: 20)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
