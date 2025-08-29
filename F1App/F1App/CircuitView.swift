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
    let lineColor: Color
    let lineWidth: CGFloat
    let sizeScale: CGFloat
    let backgroundColor: Color
    struct DriverSelection: Identifiable {
        let driver: DriverInfo
        let point: LocationPoint
        var id: Int { driver.driver_number }
    }
    @State private var selectedDriver: DriverSelection?

    init(
        coordinatesJSON: String?,
        viewModel: HistoricalRaceViewModel,
        lineColor: Color = .white,
        lineWidth: CGFloat = 4,
        sizeScale: CGFloat = 1.0,
        backgroundColor: Color = Color.gray.opacity(0.1)
    ) {
        self.coordinatesJSON = coordinatesJSON
        self.viewModel = viewModel
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.sizeScale = sizeScale
        self.backgroundColor = backgroundColor
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
                let size = min(geo.size.width, geo.size.height) * sizeScale
                let xOffset = (geo.size.width - size) / 2
                let yOffset = (geo.size.height - size) / 2

                ZStack {
                    Path { path in
                        let first = points[0]
                        path.move(to: CGPoint(x: first.x * size + xOffset, y: first.y * size + yOffset))
                        for point in points.dropFirst() {
                            path.addLine(to: CGPoint(x: point.x * size + xOffset, y: point.y * size + yOffset))
                        }
                        path.closeSubpath()
                    }
                    .stroke(lineColor, lineWidth: lineWidth)

                    ForEach(viewModel.drivers) { driver in
                        if let loc = viewModel.currentPosition[driver.driver_number] {
                            let p = viewModel.point(for: loc, in: CGSize(width: size, height: size))
                            let positioned = CGPoint(x: p.x + xOffset, y: p.y + yOffset)

                            Button {
                                if let loc = viewModel.currentPosition[driver.driver_number] {
                                    selectedDriver = DriverSelection(driver: driver, point: loc)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(driver.initials)
                                        .font(.caption2)
                                        .offset(y: -10)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .position(positioned)
                        }
                    }
                }
                .animation(.linear(duration: 1), value: viewModel.stepIndex)
                .background(backgroundColor)
                .cornerRadius(8)
                .sheet(item: $selectedDriver) { selection in
                    if let sk = viewModel.sessionKey {
                        DriverDetailView(
                            driver: selection.driver,
                            sessionKey: sk,
                            raceViewModel: viewModel
                        )
                    }

                }
            }
        }
    }
}
