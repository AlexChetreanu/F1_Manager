//
//  RaceViewModel.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import Foundation
import Combine

class RacesViewModel: ObservableObject {
    @Published var races = [Race]()

    struct OpenF1Meeting: Decodable {
        let meeting_key: Int
        let circuit_short_name: String?
        let location: String
        let meeting_name: String
        let date_start: String
    }

    func fetchRaces(year: Int) {
        guard let url = URL(string: "https://api.openf1.org/v1/meetings?year=\(year)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let decoded = try? JSONDecoder().decode([OpenF1Meeting].self, from: data) {
                    let formatter = ISO8601DateFormatter()
                    let now = Date()
                    let races = decoded
                        .filter { $0.meeting_name.contains("Grand Prix") }
                        .map { meeting -> Race in
                            let dateString = String(meeting.date_start.prefix(10))
                            let status: String
                            if let date = formatter.date(from: meeting.date_start) {
                                status = date < now ? "finished" : "upcoming"
                            } else {
                                status = "unknown"
                            }
                            return Race(
                                id: meeting.meeting_key,
                                name: meeting.meeting_name,
                                circuit_id: meeting.circuit_short_name,
                                location: meeting.location,
                                date: dateString,
                                status: status,
                                coordinates: nil
                            )
                        }
                    DispatchQueue.main.async {
                        self.races = races
                    }
                } else {
                    print("Decoding failed")
                }
            } else if let error = error {
                print("Error fetching races:", error)
            }
        }.resume()
    }
}
