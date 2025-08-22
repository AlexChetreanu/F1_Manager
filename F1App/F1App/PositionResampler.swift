import Foundation
import simd

/// Represents a single driver sample at a specific time.
public struct PositionSample: Identifiable {
    public let t: TimeInterval
    public var x: Double
    public var y: Double
    public var v: Double?
    public var gear: Int?
    public var id: TimeInterval { t }

    public init(t: TimeInterval, x: Double, y: Double, v: Double? = nil, gear: Int? = nil) {
        self.t = t
        self.x = x
        self.y = y
        self.v = v
        self.gear = gear
    }
}

/// Resamples irregular position data to a fixed stride and applies smoothing.
public final class PositionResampler {
    private let stride: TimeInterval
    private let filterX: OneEuroFilter
    private let filterY: OneEuroFilter

    public init(stride: TimeInterval = 0.20) {
        self.stride = stride
        self.filterX = OneEuroFilter()
        self.filterY = OneEuroFilter()
    }

    /// Resample the provided samples using linear/Catmull-Rom interpolation
    /// and One-Euro filtering. No NaN/Inf values are produced.
    public func resample(samples: [PositionSample]) -> [PositionSample] {
        guard let first = samples.first, let last = samples.last else { return [] }
        var result: [PositionSample] = []
        var t = first.t
        var idx = 0
        var lastOut: PositionSample?
        while t <= last.t {
            while idx + 1 < samples.count && samples[idx + 1].t < t { idx += 1 }
            var s = interpolate(at: t, index: idx, samples: samples)
            // Smoothing
            s.x = filterX.filter(value: s.x, timestamp: t)
            s.y = filterY.filter(value: s.y, timestamp: t)
            if let prev = lastOut {
                let dx = s.x - prev.x
                let dy = s.y - prev.y
                if (dx*dx + dy*dy).squareRoot() > 400 { // outlier clamp
                    
                    s.x = filterX.last
                    s.y = filterY.last
                }
            }
            result.append(s)
            lastOut = s
            t += stride
        }
        return result
    }

    private func interpolate(at t: TimeInterval, index i: Int, samples: [PositionSample]) -> PositionSample {
        let a = samples[i]
        if i + 1 >= samples.count { return a }
        let b = samples[i + 1]
        let dt = b.t - a.t
        if dt <= 0 { return b }
        if dt > 1.0 { // big gap -> teleport
            return PositionSample(t: t, x: b.x, y: b.y, v: b.v, gear: b.gear)
        }
        let u = (t - a.t) / dt
        if i > 0 && i + 2 < samples.count {
            let p0 = simd_double2(samples[i-1].x, samples[i-1].y)
            let p1 = simd_double2(a.x, a.y)
            let p2 = simd_double2(b.x, b.y)
            let p3 = simd_double2(samples[i+2].x, samples[i+2].y)
            let p = catmullRom(p0: p0, p1: p1, p2: p2, p3: p3, t: u)
            return PositionSample(t: t, x: p.x, y: p.y, v: lerp(a.v, b.v, u), gear: b.gear)
        } else {
            let x = a.x + (b.x - a.x) * u
            let y = a.y + (b.y - a.y) * u
            return PositionSample(t: t, x: x, y: y, v: lerp(a.v, b.v, u), gear: b.gear)
        }
    }

    private func catmullRom(p0: simd_double2, p1: simd_double2, p2: simd_double2, p3: simd_double2, t: Double) -> simd_double2 {
        let t2 = t * t
        let t3 = t2 * t
        let a = -0.5 * t3 + t2 - 0.5 * t
        let b = 1.5 * t3 - 2.5 * t2 + 1.0
        let c = -1.5 * t3 + 2.0 * t2 + 0.5 * t
        let d = 0.5 * t3 - 0.5 * t2
        return a * p0 + b * p1 + c * p2 + d * p3
    }

    private func lerp(_ a: Double?, _ b: Double?, _ t: Double) -> Double? {
        guard let a = a, let b = b else { return a ?? b }
        return a + (b - a) * t
    }
}

/// One-Euro filter implementation for smoothing noisy signals.
final class OneEuroFilter {
    private let minCutoff: Double
    private let beta: Double
    private let dCutoff: Double
    private var lastTime: Double?
    fileprivate let xFilter = LowPassFilter()
    private let dxFilter = LowPassFilter()

    init(minCutoff: Double = 1.2, beta: Double = 0.01, dCutoff: Double = 1.5) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    var last: Double { xFilter.last }

    func filter(value: Double, timestamp: Double) -> Double {
        guard value.isFinite else { return 0 }
        if let last = lastTime {
            let dt = timestamp - last
            let edx = dxFilter.filter((value - xFilter.last)/max(dt, 1e-6), alpha: smoothingFactor(tau: 1.0/(2*Double.pi*dCutoff), dt: dt))
            let cutoff = minCutoff + beta * abs(edx)
            let alpha = smoothingFactor(tau: 1.0/(2*Double.pi*cutoff), dt: dt)
            lastTime = timestamp
            return xFilter.filter(value, alpha: alpha)
        } else {
            reset(to: value, timestamp: timestamp)
            return value
        }
    }

    func reset(to value: Double, timestamp: Double) {
        lastTime = timestamp
        xFilter.reset(to: value)
        dxFilter.reset(to: 0)
    }

    private func smoothingFactor(tau: Double, dt: Double) -> Double {
        let r = tau / max(dt, 1e-6)
        return 1.0 / (1.0 + r)
    }

    final class LowPassFilter {
        fileprivate var last: Double = 0
        private var initialized = false

        func filter(_ value: Double, alpha: Double) -> Double {
            let a = max(0, min(1, alpha))
            if !initialized {
                initialized = true
                last = value
                return value
            }
            last = a * value + (1 - a) * last
            return last
        }

        func reset(to value: Double) {
            initialized = true
            last = value
        }
    }
}
