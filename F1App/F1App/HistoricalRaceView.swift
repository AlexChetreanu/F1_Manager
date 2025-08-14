import SwiftUI

struct HistoricalRaceView: View {
    let race: Race
    @StateObject private var viewModel = HistoricalRaceViewModel()

    var body: some View {
        VStack {
            HStack {
                TextField("Anul", text: $viewModel.year)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Caută") {
                    viewModel.load(for: race)
                }
            }
            .padding()

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.bottom)
            }

            if !viewModel.trackPoints.isEmpty && !viewModel.currentPosition.isEmpty {
                GeometryReader { geo in
                    ZStack {
                        Path { path in
                            guard let first = viewModel.trackPoints.first else { return }
                            path.move(to: CGPoint(x: first.x * geo.size.width,
                                                  y: first.y * geo.size.height))
                            for p in viewModel.trackPoints.dropFirst() {
                                path.addLine(to: CGPoint(x: p.x * geo.size.width,
                                                         y: p.y * geo.size.height))
                            }
                            path.closeSubpath()
                        }
                        .stroke(Color.blue, lineWidth: 2)

                        ForEach(viewModel.drivers) { driver in
                            if let loc = viewModel.currentPosition[driver.driver_number] {
                                let point = viewModel.point(for: loc, in: geo.size)
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .position(point)
                                Text(driver.initials)
                                    .font(.caption2)
                                    .position(x: point.x, y: point.y - 10)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding()

                Button(viewModel.isRunning ? "Pauză" : "Start") {
                    viewModel.isRunning ? viewModel.pause() : viewModel.start()
                }
                .padding(.bottom)
            }
            Spacer()
        }
    }
}
