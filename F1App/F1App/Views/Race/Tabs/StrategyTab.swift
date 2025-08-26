import SwiftUI

struct StrategyTab: View {
    var drivers: [DriverStrategyData]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.Spacing.m) {
                ForEach(drivers) { driver in
                    VStack(alignment: .leading, spacing: Layout.Spacing.s) {
                        Text(driver.name)
                            .font(.headline)
                        StintBar(stints: driver.stints)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    StrategyTab(drivers: RaceDetailData.sample.drivers)
        .background(AppColors.bg)
}
