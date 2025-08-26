import SwiftUI

struct CircuitTab: View {
    var race: RaceDetailData
    @StateObject private var viewModel = HistoricalRaceViewModel()

    var body: some View {
        VStack(spacing: Layout.Spacing.l) {
            if let coords = race.coordinates {
                CircuitView(coordinatesJSON: coords, viewModel: viewModel)
                    .frame(height: 250)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface)
                    .frame(height: 250)
                    .overlay(Text("Harta indisponibilă"))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Layout.Spacing.l), count: 2), spacing: Layout.Spacing.l) {
                ForEach(race.trackFacts) { fact in
                    VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                        Text(fact.label)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSec)
                        Text(fact.value)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
    }
}

#Preview {
    CircuitTab(race: .sample)
        .background(AppColors.bg)
}
