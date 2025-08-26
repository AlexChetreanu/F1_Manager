import SwiftUI

struct RaceSummaryHeader: View {
    var race: RaceDetailData
    @EnvironmentObject var colorStore: TeamColorStore

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.l) {
            HStack(spacing: Layout.Spacing.s) {
                Chip(text: "Finalizată", systemImage: "checkmark")
                Chip(text: "Runda \(race.round)")
                Chip(text: race.date.formatted(date: .numeric, time: .omitted))
                Spacer()
                Button(action: {}) { Image(systemName: "square.and.arrow.up") }
                Button(action: {}) { Image(systemName: "star") }
            }
            .foregroundStyle(AppColors.textPri)

            HStack(spacing: Layout.Spacing.m) {
                podiumView(position: "P1", driver: race.p1)
                podiumView(position: "P2", driver: race.p2)
                podiumView(position: "P3", driver: race.p3)
            }

            HStack(spacing: Layout.Spacing.m) {
                StatPill(icon: "timer", title: "Fastest", value: race.fastestLap.time)
                StatPill(icon: "car.side", title: "SC/VSC", value: "\(race.scCount)/\(race.vscCount)")
                StatPill(icon: "wrench.and.screwdriver", title: "Pit Δ", value: race.pitDelta)
                StatPill(icon: race.weatherIcon, title: "Vreme", value: race.weatherTemp)
            }
        }
        .padding()
        .background(AppColors.surface)
    }

    func podiumView(position: String, driver: DriverResultData) -> some View {
        HStack(spacing: Layout.Spacing.s) {
            Circle()
                .fill(colorStore.color(forTeamName: driver.team))
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(position) • \(driver.name)")
                    .font(.headline)
                Text(driver.team)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSec)
            }
        }
    }
}

#Preview {
    RaceSummaryHeader(race: .sample)
        .environmentObject(TeamColorStore(service: PreviewColorService()))
        .background(AppColors.bg)
}
