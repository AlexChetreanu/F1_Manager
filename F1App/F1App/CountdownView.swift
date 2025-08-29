import SwiftUI

struct CountdownView: View {
    let dateString: String
    @State private var timeRemaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            timeBox(value: components.days, label: "Zile")
            timeBox(value: components.hours, label: "Ore")
            timeBox(value: components.minutes, label: "Minute")
        }
        .onReceive(timer) { _ in updateTime() }
        .onAppear { updateTime() }
    }

    private func timeBox(value: Int, label: String) -> some View {
        VStack {
            Text(String(format: "%02d", value))
                .font(.title2)
                .bold()
            Text(label)
                .font(.caption)
        }
        .padding(6)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black, lineWidth: 2)
        )
        .foregroundColor(.black)
    }

    private var components: (days: Int, hours: Int, minutes: Int) {
        let total = max(Int(timeRemaining), 0)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        return (days, hours, minutes)
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

