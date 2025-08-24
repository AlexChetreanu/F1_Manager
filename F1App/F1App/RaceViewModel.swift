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
        Task {
            do {
                let races: [Race] = try await getJSON("/api/races")
                await MainActor.run { self.races = races }
            } catch {
                print("Error fetching races:", error)
            }
        }
    }
}
