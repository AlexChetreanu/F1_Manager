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
                        Text("Status: \(race.status)")
                            .font(.caption)
                            .foregroundColor(statusColor(race.status))
                    }
                    .padding(8)
                }
            }
            .navigationTitle("F1 Circuits")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.fetchRaces()
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
