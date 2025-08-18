import Foundation
import Combine

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let when = ISO8601DateFormatter().string(from: Date())
    let title: String
    let detail: String
}

final class DebugLogger: ObservableObject {
    @Published var entries: [DebugLogEntry] = []
    func log(_ title: String, _ detail: String = "") {
        DispatchQueue.main.async {
            self.entries.append(DebugLogEntry(title: title, detail: detail))
            if self.entries.count > 500 { self.entries.removeFirst(self.entries.count - 500) }
            print("📋 [DBG] \(title)\n\(detail)")
        }
    }
    func clear() { entries.removeAll() }
}
