import SwiftUI

/// Loads an image and shows only the top portion with a small zoom.
/// The visible height is roughly the top 30% of a 16:9 image.
struct TopCroppedAsyncImage: View {
    let url: URL
    private let visibleRatio = 0.3

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { image in
                image.resizable()
                    .scaledToFill()
                    .scaleEffect(1.1, anchor: .top)
                    .frame(width: geo.size.width,
                           height: geo.size.height / visibleRatio,
                           alignment: .top)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        }
        .aspectRatio(16 / (9 * visibleRatio), contentMode: .fit)
    }
}

#Preview {
    TopCroppedAsyncImage(url: URL(string: "https://example.com/image.jpg")!)
}
