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
                if race.status.lowercased() == "finished" {
                    RaceResultsView(race: race, viewModel: viewModel)
                        .padding()
                } else {
                    ZStack {
                        if isUpcomingRace {
                            Image("nahuui")
                                .resizable()
                                .scaledToFill()
                                .overlay(
                                    RadialGradient(
                                        gradient: Gradient(colors: [Color.white.opacity(0), Color.white.opacity(0.6)]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: UIScreen.main.bounds.width
                                    )
                                )
                                .clipped()
                        }
                        CircuitView(
                            coordinatesJSON: race.coordinates,
                            viewModel: viewModel,
                            lineColor: isUpcomingRace ? Color(hex: "ce2d1e") : .white,
                            lineWidth: isUpcomingRace ? 6 : 4,
                            sizeScale: isUpcomingRace ? 0.9 : 1.0,
                            backgroundColor: isUpcomingRace ? Color(hex: "37373d") : Color.gray.opacity(0.1)
                        )
                    }
                    .frame(height: UIScreen.main.bounds.height / 2)
                    .padding()
                    if isUpcomingRace {
                        VStack(spacing: 4) {
                            Text("START IN")
                                .font(.headline)
                            CountdownView(dateString: race.date)
                        }
                        .padding()
                    }
                }
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
        .onAppear {
            viewModel.year = String(race.date.prefix(4))
            viewModel.load(for: race)
        }
    }
    private var isUpcomingRace: Bool {
        guard let date = parseRaceDate(race.date) else { return false }
        return date > Date()
    }
    private func parseRaceDate(_ str: String) -> Date? {
        if let iso = ISO8601DateFormatter().date(from: str) { return iso }
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = f.date(from: str) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }
}
