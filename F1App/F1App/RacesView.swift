//
//  RacesView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//
import SwiftUI

struct RacesView: View {
    @StateObject private var viewModel = RacesViewModel()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        NavigationView {
            VStack {
                Picker("Year", selection: $selectedYear) {
                    ForEach((1950...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) {
                        Text("\($0)").tag($0)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Button("Start Race") {
                    viewModel.fetchRaces(year: selectedYear)
                }
                .buttonStyle(.borderedProminent)

                List(viewModel.races) { race in
                    NavigationLink(destination: RaceDetailView(race: race)) {
                        VStack(alignment: .leading) {
                            Text(race.location).font(.headline)
                            Text("Date: \(race.date)").font(.subheadline)
                            Text("Status: \(race.status)")
                                .font(.caption)
                                .foregroundColor(statusColor(race.status))
                        }
                        .padding(8)
                    }
                }
            }
            .navigationTitle("F1 Races")
            .onAppear {
                viewModel.fetchRaces(year: selectedYear)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "finished", "in progress":
            return .green
        case "cancelled":
            return .red
        default:
            return .yellow
        }
    }
}
