import SwiftUI

struct CountdownView: View {
    let targetDate: Date
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(timeRemaining)
            .font(.headline)
            .onReceive(timer) { _ in
                now = Date()
            }
    }

    private var timeRemaining: String {
        let diff = Int(targetDate.timeIntervalSince(now))
        if diff <= 0 { return "Cursa a început" }
        let days = diff / 86_400
        let hours = (diff % 86_400) / 3_600
        let minutes = (diff % 3_600) / 60
        let seconds = diff % 60
        if days > 0 {
            return String(format: "%dd %02dh %02dm %02ds", days, hours, minutes, seconds)
        } else {
            return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
        }
    }
}

