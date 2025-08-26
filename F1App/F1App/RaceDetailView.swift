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

    private var raceDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: race.date)
    }

    var body: some View {
        VStack {
            Picker("Select Section", selection: $selectedTab) {
                Text("Circuit").tag(0)
                Text("Strategie").tag(1)
                Text("Curse istorice").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Spacer()
            
            if selectedTab == 0 {
                if race.date.hasPrefix("2025") && race.status.lowercased() == "finished" {
                    RaceResultsView(race: race)
                } else {
                    VStack {
                        CircuitView(coordinatesJSON: race.coordinates, viewModel: viewModel)
                            .frame(height: UIScreen.main.bounds.height / 2)
                            .padding()
                        if let d = raceDate {
                            CountdownView(targetDate: d)
                                .padding(.bottom)
                        }
                    }
                }
            } else if selectedTab == 1 {
                List(viewModel.strategySuggestions) { s in
                    NavigationLink(destination: StrategyDetailView(suggestion: s)) {
                        VStack(alignment: .leading) {
                            Text(s.driver_name ?? "Driver \(s.driver_number ?? 0)").font(.headline)
                            Text(s.advice).bold()
                            Text(s.why).font(.caption)
                        }
                    }
                }
                .onAppear {
                    if let mk = viewModel.meetingKey {
                        viewModel.startStrategyUpdates(meetingKey: mk)
                    }
                }
                .onDisappear { viewModel.stopStrategyUpdates() }
            } else {
                HistoricalRaceView(race: race, viewModel: viewModel)
            }
            
            Spacer()
        }
        .navigationTitle(race.location)
        .navigationBarTitleDisplayMode(.inline)
    }
}
