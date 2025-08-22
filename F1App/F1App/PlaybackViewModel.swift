import Foundation
import SwiftUI
import simd

private struct ABState { var x: Double; var y: Double; var vx: Double; var vy: Double; var t: Double }
private final class ABFilter2D {
    let alpha: Double, beta: Double
    private var state: [String: ABState] = [:]
    init(alpha: Double = 0.7, beta: Double = 0.05) { self.alpha = alpha; self.beta = beta }
    func reset(id: String, to p: SIMD2<Double>, time: Double) { state[id] = ABState(x: p.x, y: p.y, vx: 0, vy: 0, t: time) }
    func update(id: String, obs p: SIMD2<Double>, time: Double) -> SIMD2<Double> {
        if state[id] == nil { reset(id: id, to: p, time: time); return p }
        var s = state[id]!; let dt = max(1e-3, time - s.t)
        let px = s.x + s.vx * dt, py = s.y + s.vy * dt
        let rx = p.x - px, ry = p.y - py
        let nx = px + alpha * rx, ny = py + alpha * ry
        let nvx = s.vx + (beta / dt) * rx, nvy = s.vy + (beta / dt) * ry
        state[id] = ABState(x: nx, y: ny, vx: nvx, vy: nvy, t: time)
        return SIMD2(nx, ny)
    }
    func velocity(id: String) -> SIMD2<Double> { state[id].map { SIMD2($0.vx, $0.vy) } ?? SIMD2.zero }
    func clear() { state.removeAll() }
}

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
    private let ab = ABFilter2D(alpha: 0.7, beta: 0.05)

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
            ab.clear()
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
        let deadband: Double = 0.6     // ignoră tremur sub ~0.6 „unități hartă”
        let vmaxPerFrame: Double = 180 // limită deplasare/100ms (tunează per circuit)

        for row in frame.drivers {
            guard nIdx < row.count, xIdx < row.count, yIdx < row.count,
                  let id = row[nIdx].string else { continue }
            let x0 = row[xIdx].double ?? 0
            let y0 = row[yIdx].double ?? 0
            let obs = SIMD2(x0, y0)

            // (opțional) pre-smooth ușor cu OneEuro existent
            let fx = self.fx[id] ?? OneEuroFilter(minCutoff: 1.0, beta: 0.01, dCutoff: 1.5)
            let fy = self.fy[id] ?? OneEuroFilter(minCutoff: 1.0, beta: 0.01, dCutoff: 1.5)
            self.fx[id] = fx; self.fy[id] = fy
            let ox = fx.filter(value: obs.x, timestamp: t)
            let oy = fy.filter(value: obs.y, timestamp: t)
            let pre = SIMD2(ox, oy)

            // Alpha-Beta (predict+correct)
            var p = ab.update(id: id, obs: pre, time: t)

            // deadband: dacă mișcarea e foarte mică vs ultimul publicat, păstrează
            if let lp = lastPublished[id] {
                let d = hypot(p.x - lp.x, p.y - lp.y)
                if d < deadband { p = lp }
            }

            // cap de viteză per frame (taie spike-uri scurte)
            if let lp = lastPublished[id] {
                let dx = p.x - lp.x, dy = p.y - lp.y
                let d = hypot(dx, dy)
                if d > vmaxPerFrame {
                    let scale = vmaxPerFrame / d
                    p = SIMD2(lp.x + dx*scale, lp.y + dy*scale)
                    // resetează și filtrele dacă a fost o teleportare reală
                    if d > 400 {
                        fx.reset(to: obs.x, timestamp: t)
                        fy.reset(to: obs.y, timestamp: t)
                        ab.reset(id: id, to: obs, time: t)
                        p = obs
                    }
                }
            }

            lastPublished[id] = p
            positions.append(.init(id: id, x: p.x, y: p.y, color: .red))
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
