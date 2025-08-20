import SwiftUI

struct HistoricalRaceView: View {
    let race: Race
    @ObservedObject var viewModel: HistoricalRaceViewModel
    @State private var showDebug = false
    struct DriverSelection: Identifiable {
        let driver: DriverInfo
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
                                                selectedDriver = DriverSelection(driver: driver)
                                            }
                                        Text(driver.initials)
                                            .font(.caption2)
                                            .position(x: point.x, y: point.y - 10)
                                        if let leader = viewModel.drivers.first,
                                           leader.driver_number == driver.driver_number,
                                           let line = perpendicularLine(at: point, size: geo.size) {
                                            Path { path in
                                                path.move(to: line.start)
                                                path.addLine(to: line.end)
                                            }
                                            .stroke(Color.primary, lineWidth: 1)
                                        }
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

                if let overtake = viewModel.overtakeMessage {
                    Text(overtake)
                        .padding(8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                }

                if !viewModel.raceControlMessages.isEmpty {
                    List(viewModel.raceControlMessages) { msg in
                        HStack(alignment: .top) {
                            if let lap = msg.lapNumber {
                                Text("Tur \(lap)")
                                    .bold()
                            }
                            Text(msg.message ?? "")
                                .font(.caption)
                        }
                    }
                    .frame(maxHeight: 200)
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
                             raceViewModel: viewModel)
        }
    }

    private func perpendicularLine(at point: CGPoint, size: CGSize) -> (start: CGPoint, end: CGPoint)? {
        let pts = viewModel.trackPoints.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        guard pts.count > 1 else { return nil }
        var nearestIndex = 0
        var minDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<(pts.count - 1) {
            let p0 = pts[i]
            let p1 = pts[i + 1]
            let segVec = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
            let segLen2 = segVec.x * segVec.x + segVec.y * segVec.y
            if segLen2 == 0 { continue }
            let t = max(0, min(1, ((point.x - p0.x) * segVec.x + (point.y - p0.y) * segVec.y) / segLen2))
            let proj = CGPoint(x: p0.x + segVec.x * t, y: p0.y + segVec.y * t)
            let dx = point.x - proj.x
            let dy = point.y - proj.y
            let dist2 = dx * dx + dy * dy
            if dist2 < minDist {
                minDist = dist2
                nearestIndex = i
            }
        }
        let p0 = pts[nearestIndex]
        let p1 = pts[(nearestIndex + 1) % pts.count]
        let tangent = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
        let len = sqrt(tangent.x * tangent.x + tangent.y * tangent.y)
        if len == 0 { return nil }
        let normal = CGPoint(x: -tangent.y / len, y: tangent.x / len)
        // The circle has an 8pt diameter; draw a short 16pt line (double the circle)
        let lineLength: CGFloat = 16
        let half = lineLength / 2
        let start = CGPoint(x: point.x - normal.x * half, y: point.y - normal.y * half)
        let end = CGPoint(x: point.x + normal.x * half, y: point.y + normal.y * half)
        return (start, end)
    }
}
