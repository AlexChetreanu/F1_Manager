//
//  HomeView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

struct HomeView: View {
    @StateObject private var newsStore = NewsStore()

    var body: some View {
        NavigationView {
            List {
                Section("Știri F1 (Autosport)") {
                    ForEach(newsStore.items, id: \.id) { item in
                        NavigationLink(destination: NewsDetailView(item: item)) {
                            NewsCard(item: item)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Acasă")
            .task { await newsStore.loadIfNeeded() }
            .refreshable { await newsStore.refresh() }
        }
    }
}
