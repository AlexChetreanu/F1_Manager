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

    func fetchRaces() {
        guard let url = URL(string: "\(APIConfig.baseURL)/api/races") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let decoded = try? JSONDecoder().decode([Race].self, from: data) {
                    DispatchQueue.main.async {
                        self.races = decoded
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
