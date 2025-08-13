import SwiftUI

struct HistoricRaceView: View {
    let coordinatesJSON: String?
    let circuitId: String

    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @StateObject private var viewModel = HistoricRaceViewModel()

    // MARK: - Nested Models
    struct Driver: Identifiable {
        let id = UUID()
        let code: String
        let fullName: String
        let team: String
        let color: Color
        let offset: Int
        let tyres: [String]
        let pitStops: Int
        let bestLap: String
    }

    struct RaceStats {
        let trackTemperature: String
        let airTemperature: String
        let windSpeed: String
        let fastestLap: String
        let fastestDriver: String
        let totalLaps: Int
        let pitStops: Int
        let safetyCars: Int
    }

    // MARK: - Placeholder Data
    @State private var drivers: [Driver] = [
        Driver(code: "VER", fullName: "Max Verstappen", team: "Red Bull", color: .blue, offset: 0, tyres: ["Soft", "Medium"], pitStops: 2, bestLap: "1:30.123"),
        Driver(code: "HAM", fullName: "Lewis Hamilton", team: "Mercedes", color: .green, offset: 20, tyres: ["Medium", "Hard"], pitStops: 1, bestLap: "1:30.456"),
        Driver(code: "NOR", fullName: "Lando Norris", team: "McLaren", color: .orange, offset: 40, tyres: ["Soft", "Hard"], pitStops: 2, bestLap: "1:31.001")
    ]

    let stats = RaceStats(
        trackTemperature: "35°C",
        airTemperature: "25°C",
        windSpeed: "10 km/h",
        fastestLap: "1:30.123",
        fastestDriver: "Max Verstappen",
        totalLaps: 58,
        pitStops: 36,
        safetyCars: 1
    )

    // MARK: - Animation State
    @State private var currentStep: Int = 0
    @State private var isAnimating = false
    @State private var timer: Timer? = nil
    @State private var selectedDriver: Driver? = nil

    // MARK: - Helpers
    func parseCoordinates() -> [CGPoint] {
        guard
            let jsonString = coordinatesJSON,
            let data = jsonString.data(using: .utf8),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[Double]]
        else {
            return []
        }

        let lons = arr.map { $0[0] }
        let lats = arr.map { $0[1] }

        guard let minLon = lons.min(), let maxLon = lons.max(),
              let minLat = lats.min(), let maxLat = lats.max() else {
            return []
        }

        return arr.map { point in
            let x = (point[0] - minLon) / (maxLon - minLon)
            let y = 1 - (point[1] - minLat) / (maxLat - minLat)
            return CGPoint(x: x, y: y)
        }
    }

    func startAnimation(with count: Int) {
        isAnimating = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            currentStep = (currentStep + 1) % count
        }
    }

    func stopAnimation() {
        isAnimating = false
        timer?.invalidate()
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Year", selection: $selectedYear) {
                ForEach((1950...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) {
                    Text("\($0)").tag($0)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .center)
            .onChange(of: selectedYear) { year in
                viewModel.fetchRace(circuitId: circuitId, year: year)
            }

            Text("Last held on: \(viewModel.race?.date ?? "-")")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            GeometryReader { geo in
                let points = parseCoordinates()
                ZStack {
                    if !points.isEmpty {
                        Path { path in
                            let first = points[0]
                            path.move(to: CGPoint(x: first.x * geo.size.width, y: first.y * geo.size.height))
                            for point in points.dropFirst() {
                                path.addLine(to: CGPoint(x: point.x * geo.size.width, y: point.y * geo.size.height))
                            }
                        }
                        .stroke(Color.gray, lineWidth: 2)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)

                        ForEach(drivers) { driver in
                            let idx = (currentStep + driver.offset) % max(points.count, 1)
                            let pos = points.isEmpty ? .zero : points[idx]
                            DriverMarker(driver: driver)
                                .position(x: pos.x * geo.size.width, y: pos.y * geo.size.height)
                                .onTapGesture {
                                    selectedDriver = driver
                                }
                        }
                    } else {
                        Text("No track data")
                    }
                }
            }
            .frame(height: 250)

            Button(isAnimating ? "Stop Race Replay" : "Start Race Replay") {
                if isAnimating {
                    stopAnimation()
                } else {
                    let count = parseCoordinates().count
                    if count > 0 {
                        startAnimation(with: count)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text("Track Temp: \(stats.trackTemperature)")
                Text("Air Temp: \(stats.airTemperature)")
                Text("Wind: \(stats.windSpeed)")
                Text("Fastest Lap: \(stats.fastestLap) - \(stats.fastestDriver)")
                Text("Total Laps: \(stats.totalLaps)")
                Text("Pit Stops: \(stats.pitStops)")
                Text("Safety Cars: \(stats.safetyCars)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding()
        .sheet(item: $selectedDriver) { driver in
            DriverDetailCard(driver: driver)
        }
        .onAppear {
            viewModel.fetchRace(circuitId: circuitId, year: selectedYear)
        }
    }
}

// MARK: - Supporting Views
struct DriverMarker: View {
    let driver: HistoricRaceView.Driver
    var body: some View {
        VStack(spacing: 2) {
            Text(driver.code)
                .font(.caption2)
                .bold()
            Circle()
                .fill(driver.color)
                .frame(width: 10, height: 10)
        }
    }
}

struct DriverDetailCard: View {
    let driver: HistoricRaceView.Driver
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(driver.fullName).font(.headline)
            Text(driver.team)
            Text("Tyres: \(driver.tyres.joined(separator: ", "))")
            Text("Pit stops: \(driver.pitStops)")
            Text("Best lap: \(driver.bestLap)")
        }
        .padding()
        .presentationDetents([.medium])
    }
}

#Preview {
    HistoricRaceView(coordinatesJSON: "[[0,0],[1,0],[1,1],[0,1]]", circuitId: "demo")
}

