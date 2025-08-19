import Foundation
import SwiftUI
import simd

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
    private let strideMs: Int = 100
    private var fx: [String: OneEuroFilter] = [:]
    private var fy: [String: OneEuroFilter] = [:]
    private var lastPublished: [String: SIMD2<Double>] = [:]

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
            self.fx.removeAll()
            self.fy.removeAll()
            lastPublished.removeAll()
            prefetch(from: time, to: time.addingTimeInterval(10))
        }
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: Double(strideMs) / 1000.0 / speed, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard isPlaying, let frame = buffer.first else { return }
        buffer.removeFirst()
        currentFrame = frame

        guard let nIdx = frame.fields.firstIndex(of: "n"),
              let xIdx = frame.fields.firstIndex(of: "x"),
              let yIdx = frame.fields.firstIndex(of: "y") else { return }

        var positions: [TrackView.DriverPos] = []
        positions.reserveCapacity(frame.drivers.count)
        let t = frame.t.timeIntervalSince1970
        let jumpThreshold: Double = 450 // ajustează per circuit

        for row in frame.drivers {
            guard nIdx < row.count, xIdx < row.count, yIdx < row.count,
                  let id = row[nIdx].string else { continue }
            let x0 = row[xIdx].double ?? 0
            let y0 = row[yIdx].double ?? 0

            let fx = self.fx[id] ?? OneEuroFilter(minCutoff: 0.8, beta: 0.007, dCutoff: 1.5)
            let fy = self.fy[id] ?? OneEuroFilter(minCutoff: 0.8, beta: 0.007, dCutoff: 1.5)
            self.fx[id] = fx; self.fy[id] = fy

            var xs = fx.filter(value: x0, timestamp: t)
            var ys = fy.filter(value: y0, timestamp: t)

            if let p = lastPublished[id] {
                let dx = xs - p.x, dy = ys - p.y
                if (dx*dx + dy*dy).squareRoot() > jumpThreshold {
                    fx.reset(to: x0, timestamp: t)
                    fy.reset(to: y0, timestamp: t)
                    xs = fx.filter(value: x0, timestamp: t)
                    ys = fy.filter(value: y0, timestamp: t)
                }
            }
            lastPublished[id] = SIMD2(xs, ys)
            positions.append(.init(id: id, x: xs, y: ys, color: .red))
        }

        let dur = Double(strideMs) / 1000.0 / max(0.1, speed)
        withAnimation(.linear(duration: dur)) {
            self.currentPositions = positions
        }

        if buffer.count < 5 {
            let start = frame.t.addingTimeInterval(Double(strideMs) / 1000.0)
            prefetch(from: start, to: start.addingTimeInterval(4))
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
