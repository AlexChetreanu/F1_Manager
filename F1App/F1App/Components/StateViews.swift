import SwiftUI

struct QueuedView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Sugestia este în curs de procesare...")
                .bodyStyle()
                .foregroundColor(AppColors.textSecondary(scheme))
        }
        .padding()
    }
}

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text("Nicio sugestie disponibilă")
            .bodyStyle()
            .foregroundColor(AppColors.textSecondary(scheme))
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
