import SwiftUI

struct NewsDetailView: View {
    let item: NewsItem
    @State private var showSafari = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3)).aspectRatio(16/9, contentMode: .fit)
                    }
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
