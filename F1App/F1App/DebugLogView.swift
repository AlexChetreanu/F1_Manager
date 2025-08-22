import SwiftUI

struct DebugLogView: View {
    @ObservedObject var logger: DebugLogger
    var body: some View {
        NavigationView {
            List(logger.entries) { e in
                VStack(alignment: .leading, spacing: 6) {
                    Text(e.title).font(.headline)
                    if !e.detail.isEmpty {
                        Text(e.detail).font(.caption).foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(nil)
                    }
                    Text(e.when).font(.caption2).foregroundColor(.gray)
                }
            }
            .navigationTitle("Debug")
            .toolbar {
                Button("Clear") { logger.clear() }
            }
        }
    }
}
