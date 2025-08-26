import SwiftUI

struct StintBar: View {
    var stints: [StintData]

    func color(for compound: String) -> Color {
        switch compound.uppercased() {
        case "S": return .red
        case "M": return .yellow
        case "H": return .gray
        default: return .blue
        }
    }

    var body: some View {
        GeometryReader { geo in
            let totalLaps = stints.map { $0.endLap - $0.startLap + 1 }.reduce(0, +)
            HStack(spacing: 0) {
                ForEach(stints) { stint in
                    let laps = stint.endLap - stint.startLap + 1
                    color(for: stint.compound)
                        .frame(width: geo.size.width * CGFloat(laps) / CGFloat(totalLaps), height: 20)
                }
            }
        }
        .frame(height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    StintBar(stints: RaceDetailData.sample.drivers[0].stints)
        .padding()
}
