import SwiftUI

struct CountdownView: View {
    let dateString: String
    @State private var timeRemaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formattedTime)
            .font(.largeTitle)
            .padding()
            .background(Color.red)
            .cornerRadius(8)
            .foregroundColor(.white)
            .onReceive(timer) { _ in updateTime() }
            .onAppear { updateTime() }
    }

    private var formattedTime: String {
        let total = max(Int(timeRemaining), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%02dh %02dm", hours, minutes)
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

