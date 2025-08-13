//
//  HomeView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Bine ai venit în aplicația F1!")
                    .font(.title2)
                    .padding()
            }
            .navigationTitle("Acasă")
        }
    }
}
