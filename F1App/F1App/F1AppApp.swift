//
//  F1AppApp.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

@main
struct F1AppApp: App {
    @State private var showSplash = true
    @StateObject private var teamColorStore = TeamColorStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    VectorSplashView {
                        showSplash = false
                    }
                    .transition(.opacity)
                }
            }
            .environmentObject(teamColorStore)
        }
    }
}
