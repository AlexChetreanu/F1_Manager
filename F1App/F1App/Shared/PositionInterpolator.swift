import Foundation

struct TimedPoint {
    let t: TimeInterval
    let x: Double
    let y: Double
}

enum InterpolationMode {
    case linear
}

struct PositionInterpolator {
    static func interpolate(at t: TimeInterval,
                            samples: [TimedPoint],
                            mode: InterpolationMode = .linear) -> (x: Double, y: Double)? {
        guard !samples.isEmpty else { return nil }
        if t <= samples[0].t {
            return (samples[0].x, samples[0].y)
        }
        if let last = samples.last, t >= last.t {
            return (last.x, last.y)
        }
        // find bracketing points
        var lower = 0
        var upper = samples.count - 1
        while lower + 1 < upper {
            let mid = (lower + upper) / 2
            if samples[mid].t <= t {
                lower = mid
            } else {
                upper = mid
            }
        }
        let a = samples[lower]
        let b = samples[upper]
        let dt = b.t - a.t
        guard dt > 0 else { return (b.x, b.y) }
        let alpha = (t - a.t) / dt
        let x = a.x + alpha * (b.x - a.x)
        let y = a.y + alpha * (b.y - a.y)
        return (x, y)
    }
}

