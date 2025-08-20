//
//  HomeView.swift
//  F1App
//
//  Created by Alexandru Chetreanu 
//

import SwiftUI

struct HomeView: View {
    @State private var news: [NewsItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var info: String?
    private let service = NewsService()

    var body: some View {
        NavigationView {
            List {
                Section("Știri F1 (Autosport)") {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let error = error {
                        VStack {
                            Text(error)
                                .multilineTextAlignment(.center)
                            Button("Retry") { Task { await loadNews() } }
                        }
                        .frame(maxWidth: .infinity)
                    } else if news.isEmpty {
                        Text("Nicio știre disponibilă").frame(maxWidth: .infinity)
                    } else {
                        ForEach(news) { item in
                            NavigationLink(destination: NewsDetailView(item: item)) {
                                NewsCard(item: item)
                            }
                        }
                        if let info = info {
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
            .task { await loadNews() }
            .refreshable { await loadNews() }
        }
    }

    /// Loads latest F1 news for the current season.
    @MainActor
    private func loadNews() async {
        isLoading = true
        error = nil
        info = nil

        let currentYear = Calendar.current.component(.year, from: Date())
        let limit = 30

        do {
            news = try await service.fetchF1News(year: currentYear, limit: limit)
            if news.count < limit {
                info = "Doar \(news.count) din \(limit) știri disponibile pentru sezonul \(currentYear)."
            }
        } catch {
            self.error = "Eroare la încărcarea știrilor"
        }
        isLoading = false
    }
}
