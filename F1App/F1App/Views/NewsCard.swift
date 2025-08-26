import SwiftUI

struct NewsCard: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = item.imageUrl {
                TopCroppedAsyncImage(url: url)
                    .accessibilityLabel(item.title)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16 / (9 * 0.3), contentMode: .fit)
            }

            Text(item.title)
                .font(.headline)
                .lineLimit(2)

            HStack {
                Text(item.source)
                    .font(.caption)
                    .padding(4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
                Text(item.publishedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
