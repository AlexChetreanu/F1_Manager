import SwiftUI

struct QueuedView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Sugestia este în curs de procesare...")
                .bodyStyle()
                .foregroundColor(AppColors.textSecondary)
        }
        .padding()
    }
}

struct EmptyStateView: View {
    var body: some View {
        Text("Nicio sugestie disponibilă")
            .bodyStyle()
            .foregroundColor(AppColors.textSecondary)
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
            .background(AppColors.accentRed)
            .cornerRadius(8)
    }
}
