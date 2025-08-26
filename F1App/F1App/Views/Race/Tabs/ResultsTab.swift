import SwiftUI

struct ResultsTab: View {
    var results: [DriverResultData]
    @EnvironmentObject var colorStore: TeamColorStore
    @State private var filter: Filter = .top10

    enum Filter: String, CaseIterable, Identifiable {
        case top10 = "Top 10"
        case all = "Toți"
        case mine = "Echipa mea"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.m) {
            HStack {
                ForEach(Filter.allCases) { f in
                    Text(f.rawValue)
                        .font(.caption)
                        .padding(.horizontal, Layout.Spacing.m)
                        .padding(.vertical, Layout.Spacing.xs)
                        .background(filter == f ? AppColors.accent.opacity(0.2) : AppColors.surface)
                        .clipShape(Capsule())
                        .onTapGesture { withAnimation { filter = f } }
                }
            }
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: Layout.Spacing.s) {
                    ForEach(Array(results.enumerated()), id: \.0) { index, result in
                        ResultRow(position: index + 1, result: result)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    ResultsTab(results: RaceDetailData.sample.results)
        .environmentObject(TeamColorStore(service: PreviewColorService()))
}
