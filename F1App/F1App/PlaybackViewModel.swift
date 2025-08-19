import Foundation
import SwiftUI

/// View model handling buffering and playback of historical frames.
@MainActor final class PlaybackViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var speed: Double = 1.0
    @Published var currentFrame: FrameDTO?
    @Published var currentPositions: [TrackView.DriverPos] = []

    private let service = HistoricalStreamService()
    var buffer: [FrameDTO] = []
    private var timer: Timer?
    private var streamTask: Task<Void, Error>?
    private var sessionKey: Int?
    private let strideMs: Int = 200
    private var fx: [String: OneEuroFilter] = [:]
    private var fy: [String: OneEuroFilter] = [:]

    /// Prepare streaming for a session.
    func load(sessionKey: Int, from start: Date, to end: Date) {
        self.sessionKey = sessionKey
        prefetch(from: start, to: end)
    }

    /// Start playback.
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        scheduleTimer()
    }

    /// Pause playback.
    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    /// Seek to a specific time and restart prefetch.
    func seek(to time: Date) {
        pause()
        if let key = sessionKey {
            buffer.removeAll()
            prefetch(from: time, to: time.addingTimeInterval(10))
        }
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: Double(strideMs) / 1000.0 / speed, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func tick() {
        guard isPlaying else { return }
        guard !buffer.isEmpty else { return }
        let frame = buffer.removeFirst()
        currentFrame = frame

        guard let nIdx = frame.fields.firstIndex(of: "n"),
              let xIdx = frame.fields.firstIndex(of: "x"),
              let yIdx = frame.fields.firstIndex(of: "y") else { return }

        var positions: [TrackView.DriverPos] = []
        let t = frame.t.timeIntervalSince1970
        for row in frame.drivers {
            guard nIdx < row.count, xIdx < row.count, yIdx < row.count,
                  let id = row[nIdx].string else { continue }
            let x0 = row[xIdx].double ?? 0
            let y0 = row[yIdx].double ?? 0
            let fx = self.fx[id] ?? OneEuroFilter()
            let fy = self.fy[id] ?? OneEuroFilter()
            self.fx[id] = fx
            self.fy[id] = fy
            let xs = fx.filter(value: x0, timestamp: t)
            let ys = fy.filter(value: y0, timestamp: t)
            positions.append(TrackView.DriverPos(id: id, x: xs, y: ys, color: .red))
        }
        currentPositions = positions

        if buffer.count < 5, let key = sessionKey {
            let start = frame.t.addingTimeInterval(Double(strideMs) / 1000.0)
            let end = start.addingTimeInterval(4)
            prefetch(from: start, to: end)
        }
    }

    private func prefetch(from: Date, to: Date) {
        guard let key = sessionKey else { return }
        streamTask?.cancel()
        streamTask = Task {
            do {
                let stream = try await service.streamFrames(sessionKey: key, from: from, to: to, strideMs: strideMs, format: "ndjson")
                for try await frame in stream {
                    buffer.append(frame)
                }
            } catch {
                // TODO: handle streaming error
            }
        }
    }

    deinit {
        streamTask?.cancel()
        timer?.invalidate()
    }
}
