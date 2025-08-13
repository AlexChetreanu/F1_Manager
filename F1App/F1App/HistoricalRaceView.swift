import SwiftUI

struct HistoricalRaceView: View {
    let race: Race
    @StateObject private var viewModel = HistoricalRaceViewModel()
    @State private var selectedDriver: HistoricalDriver?

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Year", selection: $viewModel.selectedYear) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Text("\(year)").tag(year)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: viewModel.selectedYear) { year in
                Task { await viewModel.fetchMeeting(for: year, circuitId: race.circuit_id) }
            }

            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red).padding()
            } else if viewModel.meetingKey != nil {
                ZStack {
                    CircuitView(coordinatesJSON: race.coordinates)
                        .frame(height: 300)
                        .padding()
                    GeometryReader { geo in
                        ForEach(viewModel.drivers) { driver in
                            if let pos = driver.currentPosition {
                                Circle()
                                    .fill(Color(hex: driver.teamColorHex ?? "#FF0000"))
                                    .frame(width: 12, height: 12)
                                    .position(x: CGFloat(pos.x) * geo.size.width,
                                              y: CGFloat(1 - pos.y) * geo.size.height)
                                    .onTapGesture {
                                        selectedDriver = driver
                                    }
                                Text(driver.initials)
                                    .font(.caption2)
                                    .position(x: CGFloat(pos.x) * geo.size.width,
                                              y: CGFloat(1 - pos.y) * geo.size.height - 10)
                            }
                        }
                    }
                }
                Button("Start") {
                    viewModel.startSimulation()
                }
                .padding()

                if let weather = viewModel.weather {
                    VStack(alignment: .leading) {
                        Text("Weather:")
                        if let t = weather.air_temperature { Text("Air Temp: \(t, specifier: "%.1f")°C") }
                        if let w = weather.wind_speed { Text("Wind: \(w, specifier: "%.1f") m/s") }
                        if let h = weather.humidity { Text("Humidity: \(h, specifier: "%.0f")%") }
                        if let r = weather.rainfall { Text("Rainfall: \(r, specifier: "%.1f") mm") }
                    }
                    .padding(.horizontal)
                }

                if let best = viewModel.bestDriver {
                    Text("Best time: \(best)").padding(.horizontal)
                }

                if !viewModel.disqualifiedDrivers.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Disqualified / Retired:")
                        ForEach(viewModel.disqualifiedDrivers, id: \.self) { name in
                            Text(name)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Spacer()
        }
        .onAppear {
            viewModel.loadYears()
            Task { await viewModel.fetchMeeting(for: viewModel.selectedYear, circuitId: race.circuit_id) }
        }
        .sheet(item: $selectedDriver) { driver in
            DriverHistoricalDetailView(driver: driver, meetingKey: viewModel.meetingKey ?? 0)
        }
    }
}

struct DriverHistoricalDetailView: View {
    let driver: HistoricalDriver
    let meetingKey: Int
    @StateObject private var viewModel: DriverHistoryViewModel

    init(driver: HistoricalDriver, meetingKey: Int) {
        self.driver = driver
        self.meetingKey = meetingKey
        _viewModel = StateObject(wrappedValue: DriverHistoryViewModel(meetingKey: meetingKey, driverNumber: driver.id))
    }

    var body: some View {
        List {
            Section(header: Text(driver.name)) {
                Text("Total pit stops: \(viewModel.pitStops.count)")
                if !viewModel.pitStops.isEmpty {
                    ForEach(viewModel.pitStops, id: \.self) { stop in
                        Text("Lap \(stop.lap) - \(stop.duration ?? 0, specifier: "%.1f")s")
                    }
                }
            }
            Section(header: Text("Lap Times")) {
                ForEach(viewModel.laps, id: \.self) { lap in
                    Text("Lap \(lap.lap) - \(lap.time ?? 0, specifier: "%.3f")s")
                }
            }
            Section(header: Text("Tyres")) {
                ForEach(viewModel.stints, id: \.self) { stint in
                    Text("Laps \(stint.lap_start)-\(stint.lap_end ?? 0): \(stint.tyre_compound ?? "")")
                }
            }
            if let fastest = viewModel.fastestLap {
                Section(header: Text("Fastest Lap")) {
                    Text("Lap \(fastest.lap) - \(fastest.time ?? 0, specifier: "%.3f")s")
                }
            }
        }
    }
}

struct PitStop: Decodable, Hashable {
    let lap: Int
    let duration: Double?
}

struct LapInfo: Decodable, Hashable {
    let lap: Int
    let time: Double?
}

struct StintInfo: Decodable, Hashable {
    let lap_start: Int
    let lap_end: Int?
    let tyre_compound: String?
}

class DriverHistoryViewModel: ObservableObject {
    @Published var pitStops: [PitStop] = []
    @Published var laps: [LapInfo] = []
    @Published var stints: [StintInfo] = []
    @Published var fastestLap: LapInfo?

    let meetingKey: Int
    let driverNumber: Int

    init(meetingKey: Int, driverNumber: Int) {
        self.meetingKey = meetingKey
        self.driverNumber = driverNumber
        Task { await load() }
    }

    func load() async {
        await fetchPitStops()
        await fetchLaps()
        await fetchStints()
    }

    private func fetchPitStops() async {
        do {
            let url = URL(string: "https://api.openf1.org/v1/pit?meeting_key=\(meetingKey)&driver_number=\(driverNumber)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            pitStops = try JSONDecoder().decode([PitStop].self, from: data)
        } catch {
            print("pit error", error)
        }
    }

    private func fetchLaps() async {
        do {
            let url = URL(string: "https://api.openf1.org/v1/laps?meeting_key=\(meetingKey)&driver_number=\(driverNumber)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            laps = try JSONDecoder().decode([LapInfo].self, from: data)
            fastestLap = laps.min(by: { ($0.time ?? Double.greatestFiniteMagnitude) < ($1.time ?? Double.greatestFiniteMagnitude) })
        } catch {
            print("laps error", error)
        }
    }

    private func fetchStints() async {
        do {
            let url = URL(string: "https://api.openf1.org/v1/stints?meeting_key=\(meetingKey)&driver_number=\(driverNumber)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            stints = try JSONDecoder().decode([StintInfo].self, from: data)
        } catch {
            print("stints error", error)
        }
    }
}
