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
    
    var body: some View {
        VStack {
            Picker("Select Section", selection: $selectedTab) {
                Text("Circuit").tag(0)
                Text("Section 2").tag(1)
                Text("Section 3").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Spacer()
            
            if selectedTab == 0 {
                CircuitView(coordinatesJSON: race.coordinates)
                    .frame(height: UIScreen.main.bounds.height / 2)
                    .padding()
            } else if selectedTab == 1 {
                Text("Section 2 content").font(.title)
            } else {
                Text("Section 3 content").font(.title)
            }
            
            Spacer()
        }
        .navigationTitle(race.location)
        .navigationBarTitleDisplayMode(.inline)
    }
}
