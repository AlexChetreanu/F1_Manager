//
//  DriverStanding.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//
import SwiftUI

struct DriverStanding: Decodable {
        let id: Int
        let name: String
        let team: String
        let points: Int
        let driver_number: Int
        let country_code: String
}

extension DriverStanding {
    /// Returns the resource name for the driver's image based on their last name.
    var imageName: String {
        let lastName = name.split(separator: " ").last.map(String.init) ?? name
        switch lastName.lowercased() {
        case "russell":
            return "Russel"
        case "colapinto":
            return "Colopinto"
        default:
            return lastName.capitalized
        }
    }
}

func fetchStandings(completion: @escaping ([DriverStanding]?) -> Void) {
    let url = API.url("/api/drivers")

    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, error == nil else {
            completion(nil)
            return
        }
        let standings = try? JSONDecoder().decode([DriverStanding].self, from: data)
        completion(standings)
    }.resume()
}
