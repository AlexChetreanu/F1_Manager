//
//  DriversView.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

struct DriversView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Lista piloților")
                    .font(.title2)
                    .padding()
            }
            .navigationTitle("Piloți")
        }
    }
}
