import SwiftUI

struct QueuedView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.s) {
            ProgressView()
            Text("Sugestia este în curs de procesare...")
                .bodyStyle()
                .foregroundStyle(AppColors.textSec)
        }
        .padding()
    }
}

struct EmptyStateView: View {
    var body: some View {
        Text("Nicio sugestie disponibilă")
            .bodyStyle()
            .foregroundStyle(AppColors.textSec)
            .padding()
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .bodyStyle()
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppColors.accent)
            .cornerRadius(Layout.Radius.chip)
    }
}
