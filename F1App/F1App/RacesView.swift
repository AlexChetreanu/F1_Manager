//
//  RacesView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//
import SwiftUI

struct RacesView: View {
    @StateObject private var viewModel = RacesViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.races) { race in
                NavigationLink(destination: RaceDetailView(race: race)) {
                    VStack(alignment: .leading) {
                        Text(race.location).font(.headline)
                        Text("Date: \(race.date)").font(.subheadline)
                        Text("Status: \(race.status)").font(.caption).foregroundColor(.gray)
                    }
                    .padding(8)
                }
            }
            .navigationTitle("F1 Circuits")
            .onAppear {
                viewModel.fetchRaces()
            }
        }
    }
}
