import SwiftUI

struct Driver: Identifiable {
    let id = UUID()
    let initials: String
    let teamColor: Color
}

struct RaceReplayView: View {
    let race: Race
    @State private var inputYear: String = ""
    @State private var showRace: Bool = false

    private var raceYear: String {
        String(race.date.prefix(4))
    }

    private let sampleDrivers: [Driver] = [
        Driver(initials: "HAM", teamColor: .gray),
        Driver(initials: "VER", teamColor: .blue),
        Driver(initials: "LEC", teamColor: .red),
        Driver(initials: "NOR", teamColor: .orange)
    ]

    var body: some View {
        VStack {
            TextField("Enter year", text: $inputYear)
                .keyboardType(.numberPad)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Load Race") {
                showRace = (inputYear == raceYear)
            }
            .padding(.bottom)

            if showRace {
                CircuitView(coordinatesJSON: race.coordinates)
                    .frame(height: 200)
                    .padding(.bottom)

                Button("Start") {
                    // TODO: Implement race start logic
                }
                .padding(.bottom)

                DriverCirclesView(drivers: sampleDrivers)
                    .padding(.bottom)

                WeatherInfoView()
            } else if !inputYear.isEmpty {
                Text("No race for selected year").foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct DriverCirclesView: View {
    let drivers: [Driver]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(drivers) { driver in
                VStack {
                    Circle()
                        .fill(driver.teamColor)
                        .frame(width: 24, height: 24)
                    Text(driver.initials)
                        .font(.caption)
                }
            }
        }
    }
}

struct WeatherInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Temperature: --°C")
            Text("Wind: -- km/h")
            Text("Precipitation: --")
            Text("Best Lap: --")
            Text("Disqualified: --")
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
