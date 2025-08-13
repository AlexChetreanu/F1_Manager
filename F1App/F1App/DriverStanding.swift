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

func fetchStandings(completion: @escaping ([DriverStanding]?) -> Void) {
    guard let url = URL(string: "http://127.0.0.1:8000/api/drivers") else {
        completion(nil)
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, error == nil else {
            completion(nil)
            return
        }

        let standings = try? JSONDecoder().decode([DriverStanding].self, from: data)
        completion(standings)
    }.resume()
}
