import SwiftUI

struct EventToastView: View {
    let event: RaceEvent

    var iconName: String {
        switch event.eventType {
        case .overtake: return "arrow.up.arrow.down.circle"
        case .race_control: return "exclamationmark.triangle"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: iconName)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 2)
    }

    private var text: String {
        switch event.eventType {
        case .overtake:
            if let d1 = event.driverNumber, let d2 = event.driverNumberOvertaken, let lap = event.lap {
                return "#\(d1) a depășit #\(d2) — Lap \(lap)"
            }
            return event.message ?? "Overtake"
        case .race_control:
            return event.message ?? "Race Control"
        }
    }
}
