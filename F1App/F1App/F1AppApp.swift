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
        let color = UIColor(Color(hex: "ce2d1e"))

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = color
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = color
        UITabBar.appearance().standardAppearance = tabAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
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
            .environmentObject(teamColorStore)
        }
    }
}
