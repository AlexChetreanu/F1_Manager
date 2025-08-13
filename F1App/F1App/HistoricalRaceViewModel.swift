import SwiftUI
import Combine

struct OpenF1Meeting: Decodable {
    let meeting_key: Int
}

struct OpenF1Driver: Decodable {
    let driver_number: Int
    let full_name: String
    let team_colour: String?
}

struct DriverPosition: Decodable {
    let driver_number: Int
    let x: Double
    let y: Double
}

struct WeatherInfo: Decodable {
    let air_temperature: Double?
    let wind_speed: Double?
    let humidity: Double?
    let rainfall: Double?
}

struct RaceResult: Decodable {
    let driver_number: Int
    let status: String?
    let total_time: Double?
}

struct HistoricalDriver: Identifiable {
    let id: Int // driver_number
    let name: String
    let teamColorHex: String?
    var positions: [DriverPosition] = []
    var currentIndex: Int = 0

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.reduce("") { $0 + (parts.isEmpty ? "" : String($1.first!)) }
    }

    var currentPosition: DriverPosition? {
        guard currentIndex < positions.count else { return nil }
        return positions[currentIndex]
    }
}

@MainActor
class HistoricalRaceViewModel: ObservableObject {
    @Published var availableYears: [Int] = []
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Published var meetingKey: Int?
    @Published var drivers: [HistoricalDriver] = []
    @Published var weather: WeatherInfo?
    @Published var bestDriver: String?
    @Published var disqualifiedDrivers: [String] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var timer: Timer?

    func loadYears() {
        let currentYear = Calendar.current.component(.year, from: Date())
        availableYears = Array((currentYear-5)...currentYear).reversed()
    }

    func fetchMeeting(for year: Int, circuitKey: String) async {
        guard !circuitKey.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        meetingKey = nil
        drivers = []
        errorMessage = nil
        let urlString = "https://api.openf1.org/v1/meetings?year=\(year)&circuit_key=\(circuitKey)"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let meetings = try JSONDecoder().decode([OpenF1Meeting].self, from: data)
            guard let meeting = meetings.first else {
                errorMessage = "No race data available for this year."
                return
            }
            meetingKey = meeting.meeting_key
            await fetchDrivers()
            if let key = meetingKey {
                await fetchWeather(meetingKey: key)
                await fetchResults(meetingKey: key)
            }
        } catch {
            errorMessage = "No race data available for this year."
        }
    }

    private func fetchDrivers() async {
        guard let meetingKey else { return }
        do {
            let url = URL(string: "https://api.openf1.org/v1/drivers?meeting_key=\(meetingKey)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let driverDTOs = try JSONDecoder().decode([OpenF1Driver].self, from: data)
            drivers = driverDTOs.map { HistoricalDriver(id: $0.driver_number, name: $0.full_name, teamColorHex: $0.team_colour) }
            await fetchPositions()
        } catch {
            print("Drivers fetch error", error)
        }
    }

    private func fetchPositions() async {
        guard let meetingKey else { return }
        do {
            let url = URL(string: "https://api.openf1.org/v1/positions?meeting_key=\(meetingKey)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let positions = try JSONDecoder().decode([DriverPosition].self, from: data)
            for idx in drivers.indices {
                let driverNumber = drivers[idx].id
                drivers[idx].positions = positions.filter { $0.driver_number == driverNumber }
            }
        } catch {
            print("Positions fetch error", error)
        }
    }

    private func fetchWeather(meetingKey: Int) async {
        do {
            let url = URL(string: "https://api.openf1.org/v1/weather?meeting_key=\(meetingKey)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            weather = try JSONDecoder().decode([WeatherInfo].self, from: data).first
        } catch {
            print("Weather fetch error", error)
        }
    }

    private func fetchResults(meetingKey: Int) async {
        do {
            let url = URL(string: "https://api.openf1.org/v1/results?meeting_key=\(meetingKey)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let results = try JSONDecoder().decode([RaceResult].self, from: data)
            if let best = results.sorted(by: { ($0.total_time ?? Double.greatestFiniteMagnitude) < ($1.total_time ?? Double.greatestFiniteMagnitude) }).first,
               let driver = drivers.first(where: { $0.id == best.driver_number }) {
                bestDriver = driver.name
            }
            disqualifiedDrivers = results.compactMap { res in
                if let status = res.status, status.lowercased() != "finished" {
                    return drivers.first(where: { $0.id == res.driver_number })?.name
                }
                return nil
            }
        } catch {
            print("Results fetch error", error)
        }
    }

    func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            for idx in self.drivers.indices {
                var driver = self.drivers[idx]
                if driver.currentIndex + 1 < driver.positions.count {
                    driver.currentIndex += 1
                    self.drivers[idx] = driver
                }
            }
        }
    }
}

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
