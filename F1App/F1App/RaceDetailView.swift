//
//  RaceModelView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI
import MapKit

struct RaceDetailView: View {
    let race: Race

    @State private var selectedTab = 0
    @StateObject private var viewModel = HistoricalRaceViewModel()

    var body: some View {
        VStack {
            Picker("Select Section", selection: $selectedTab) {
                Text("Circuit").tag(0)
                Text("Section 2").tag(1)
                Text("Curse istorice").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Spacer()
            
            if selectedTab == 0 {
                CircuitView(coordinatesJSON: race.coordinates, viewModel: viewModel)
                    .frame(height: UIScreen.main.bounds.height / 2)
                    .padding()
            } else if selectedTab == 1 {
                Text("Section 2 content").font(.title)
            } else {
                HistoricalRaceView(race: race, viewModel: viewModel)
            }
            
            Spacer()
        }
        .navigationTitle(race.location)
        .navigationBarTitleDisplayMode(.inline)
    }
}
