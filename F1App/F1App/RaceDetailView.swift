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
                Text("Strategie").tag(1)
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
                VStack {
                    if let message = viewModel.errorMessage {
                        ErrorBanner(message: message)
                            .padding()
                    } else if viewModel.strategySuggestions.isEmpty {
                        QueuedView()
                            .shimmer(active: true)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Layout.Spacing.l) {
                                ForEach(viewModel.strategySuggestions) { s in
                                    let driver = viewModel.drivers.first { $0.driver_number == s.driver_number }
                                    NavigationLink(destination: StrategyDetailView(suggestion: s, driver: driver)) {
                                        StrategySuggestionCard(suggestion: s, driver: driver)
                                    }
                                }
                            }
                            .padding()
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
        .background(AppColors.bg.ignoresSafeArea())
    }
}
