import SwiftUI

struct HistoricalRaceView: View {
    let race: Race
    @ObservedObject var viewModel: HistoricalRaceViewModel
    @State private var showDebug = false
    struct DriverSelection: Identifiable {
        let driver: DriverInfo
        let point: LocationPoint
        var id: Int { driver.driver_number }
    }

    @State private var selectedDriver: DriverSelection?

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

            if !viewModel.trackPoints.isEmpty {
                GeometryReader { geo in
                    let bounds = CGRect(origin: .zero, size: geo.size)
                    let outOfBounds = viewModel.drivers.contains { driver in
                        if let loc = viewModel.currentPosition[driver.driver_number] {
                            let p = viewModel.point(for: loc, in: geo.size)
                            return !bounds.contains(p)
                        }
                        return false
                    }

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

                        if !viewModel.currentPosition.isEmpty {
                            ForEach(viewModel.drivers) { driver in
                                if let loc = viewModel.currentPosition[driver.driver_number] {
                                    let point = viewModel.point(for: loc, in: geo.size)
                                    if bounds.contains(point) {
                                        Circle()
                                            .fill(Color(hex: driver.team_color ?? "FF0000"))
                                            .frame(width: 8, height: 8)
                                            .position(point)
                                            .onTapGesture {
                                                selectedDriver = DriverSelection(driver: driver, point: loc)
                                            }
                                        Text(driver.initials)
                                            .font(.caption2)
                                            .position(x: point.x, y: point.y - 10)
                                    }
                                }
                            }
                            if outOfBounds {
                                Text("Puncte în afara circuitului")
                                    .foregroundColor(.red)
                                    .position(x: geo.size.width / 2, y: 20)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: viewModel.currentStepDuration), value: viewModel.stepIndex)
                }
                .frame(height: 300)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding()

                if viewModel.currentPosition.isEmpty && viewModel.errorMessage == nil {
                    Text("Date indisponibile")
                        .foregroundColor(.red)
                        .padding(.bottom)
                }

                if viewModel.maxSteps > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.stepIndex) },
                            set: { viewModel.stepIndex = Int($0); viewModel.updatePositions() }
                        ),
                        in: 0...Double(viewModel.maxSteps - 1),
                        step: 1
                    )
                    .padding(.horizontal)
                }

                HStack {
                    Button(viewModel.isRunning ? "Pauză" : "Start") {
                        viewModel.isRunning ? viewModel.pause() : viewModel.start()
                    }
                    Button("Viteză x\(Int(viewModel.playbackSpeed))") {
                        viewModel.cycleSpeed()
                    }
                    if viewModel.debugEnabled {
                        Button("Diagnose") {
                            viewModel.runDiagnosis(for: race)
                            showDebug = true
                        }
                    }
                }
                .padding(.bottom)

                List(viewModel.drivers) { driver in
                    if let loc = viewModel.currentPosition[driver.driver_number] {
                        HStack {
                            Text(driver.full_name)
                            Spacer()
                            Text(String(format: "(%.2f, %.2f)", loc.x, loc.y))
                                .font(.caption)
                        }
                    } else {
                        HStack {
                            Text(driver.full_name)
                            Spacer()
                            Text("N/A")
                                .font(.caption)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            Spacer()
        }
        .sheet(isPresented: $showDebug) {
            VStack {
                if let sum = viewModel.diagnosisSummary {
                    Text(sum).font(.headline).padding()
                }
                DebugLogView(logger: viewModel.logger)
            }
        }
        .sheet(item: $selectedDriver) { selection in
            DriverDetailView(driver: selection.driver,
                             sessionKey: viewModel.sessionKey,
                             location: selection.point)
        }
    }
}
