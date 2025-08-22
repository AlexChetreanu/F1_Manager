//
//  HomeView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedItem: NewsItem?

    var body: some View {
        NavigationStack {
            List {
                Section("Știri F1 (Autosport)") {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let error = viewModel.error {
                        VStack {
                            Text(error)
                                .multilineTextAlignment(.center)
                            Button("Retry") { Task { await viewModel.load() } }
                        }
                        .frame(maxWidth: .infinity)
                    } else if viewModel.items.isEmpty {
                        Text("Nicio știre disponibilă").frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.items, id: \.id) { item in
                            NewsCard(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedItem = item }
                        }
                        if let info = viewModel.info {
                            Text(info)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Acasă")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .navigationDestination(item: $selectedItem) { item in
                NewsDetailView(item: item)
            }
        }
    }
}
