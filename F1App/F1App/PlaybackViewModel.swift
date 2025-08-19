import Foundation
import SwiftUI

/// View model handling buffering and playback of historical frames.
@MainActor final class PlaybackViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var speed: Double = 1.0
    @Published var currentFrame: FrameDTO?

    private let service = HistoricalStreamService()
    private var buffer: [FrameDTO] = []
    private var timer: Timer?
    private var streamTask: Task<Void, Error>?
    private var sessionKey: Int?
    private let strideMs: Int = 200

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

    private func tick() {
        guard isPlaying else { return }
        if buffer.isEmpty { return }
        currentFrame = buffer.removeFirst()
        if buffer.count < 5, let key = sessionKey, let last = currentFrame?.t {
            let start = last.addingTimeInterval(Double(strideMs) / 1000.0)
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
