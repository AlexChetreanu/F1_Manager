//
//  CircuitView.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

struct CircuitView: View {
    let coordinatesJSON: String?
    @ObservedObject var viewModel: HistoricalRaceViewModel

    init(coordinatesJSON: String?, viewModel: HistoricalRaceViewModel) {
        self.coordinatesJSON = coordinatesJSON
        self.viewModel = viewModel
    }

    // Determine track points either from view model or by parsing JSON
    func trackPoints() -> [CGPoint] {
        if !viewModel.trackPoints.isEmpty {
            return viewModel.trackPoints
        }

        guard
            let jsonString = coordinatesJSON,
            let data = jsonString.data(using: .utf8),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]],
            !arr.isEmpty
        else {
            return []
        }

        let xs = arr.map { $0[0] }
        let ys = arr.map { $0[1] }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 1

        return arr.map { point in
            let x = (point[0] - minX) / (maxX - minX)
            let y = 1 - (point[1] - minY) / (maxY - minY)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let points = trackPoints()

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

                    if let start = viewModel.startLocation {
                        let p = viewModel.point(for: start, in: geo.size)
                        Path { startPath in
                            startPath.move(to: CGPoint(x: p.x, y: p.y - 10))
                            startPath.addLine(to: CGPoint(x: p.x, y: p.y + 10))
                        }
                        .stroke(Color.green, lineWidth: 2)
                    }

                    ForEach(viewModel.drivers) { driver in
                        if let loc = viewModel.currentPosition[driver.driver_number] {
                            let p = viewModel.point(for: loc, in: geo.size)
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
                .animation(.linear(duration: 1), value: viewModel.stepIndex)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
