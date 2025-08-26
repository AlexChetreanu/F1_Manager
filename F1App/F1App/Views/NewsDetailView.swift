import SwiftUI

struct NewsDetailView: View {
    let item: NewsItem
    @State private var showSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = item.imageUrl {
                    TopCroppedAsyncImage(url: url)
                        .accessibilityLabel(item.title)
                }

                Text(item.title)
                    .font(.title2)
                    .bold()
                Text(item.publishedAt, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(item.excerpt)
                Button("Deschide articolul") { showSafari = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(item.source)
        .sheet(isPresented: $showSafari) {
            if let url = URL(string: item.link) {
                SafariView(url: url)
            }
        }
    }
}
