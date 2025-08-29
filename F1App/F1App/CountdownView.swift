import SwiftUI

struct CountdownView: View {
    let dateString: String
    @State private var timeRemaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formattedTime)
            .font(.largeTitle)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 2)
            )
            .onReceive(timer) { _ in updateTime() }
            .onAppear { updateTime() }
    }

    private var formattedTime: String {
        let total = max(Int(timeRemaining), 0)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        return String(format: "%dd %02dh %02dm", days, hours, minutes)
    }

    private func updateTime() {
        guard let target = parseDate(dateString) else { return }
        timeRemaining = target.timeIntervalSince(Date())
    }

    private func parseDate(_ str: String) -> Date? {
        if let iso = ISO8601DateFormatter().date(from: str) { return iso }
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = f.date(from: str) { return d }
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str)
    }
}

