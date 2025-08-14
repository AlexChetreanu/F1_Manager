//
//  CircuitView.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

struct CircuitView: View {
    @ObservedObject var viewModel: HistoricalRaceViewModel

    init(coordinatesJSON: String?, viewModel: HistoricalRaceViewModel) {
        self.viewModel = viewModel
        viewModel.ensureTrack(from: coordinatesJSON)
    }

    var body: some View {
        VStack {
            GeometryReader { geo in
                let points = viewModel.trackPoints

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
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
    }
}
