//
//  F1AppApp.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI
import UIKit

@main
struct F1AppApp: App {
    @State private var showSplash = true
    @StateObject private var teamColorStore = TeamColorStore()

    init() {
        let themeColor = UIColor(hex: "ce2d1e")

        // Navigation bar styling
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = themeColor
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().barTintColor = themeColor
        UINavigationBar.appearance().tintColor = .white
        UINavigationBar.appearance().prefersLargeTitles = false

        // Tab bar styling
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = themeColor
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().barTintColor = themeColor
        UITabBar.appearance().tintColor = .white
    }

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
            .background(Color.black.ignoresSafeArea())
            .environmentObject(teamColorStore)
        }
    }
}
