//
//  ContentView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

import SwiftUI

struct ContentView: View {
    @AppStorage("token") var token: String?

    var body: some View {
        if let _ = token {
            DashboardView()
        } else {
            LoginView()
        }
    }
}


#Preview {
    ContentView()
}
