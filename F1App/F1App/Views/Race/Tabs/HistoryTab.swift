import SwiftUI

struct HistoryTab: View {
    var history: [PastRaceData]

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.m) {
                ForEach(history) { race in
                    HStack {
                        VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                            Text(race.year)
                                .font(.headline)
                            Text("Câștigător: \(race.winner)")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSec)
                            Text("Pole→Win: \(race.poleToWin)")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSec)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: Layout.Spacing.xs) {
                            Text(race.pits)
                                .font(.caption)
                            Text(race.scRate)
                                .font(.caption)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
}

#Preview {
    HistoryTab(history: RaceDetailData.sample.history)
        .background(AppColors.bg)
}
