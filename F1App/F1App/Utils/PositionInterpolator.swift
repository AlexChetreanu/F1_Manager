import Foundation

struct TimedPoint {
    let t: TimeInterval
    let x: Double
    let y: Double
}

enum InterpMode {
    case linear
}

enum PositionInterpolator {
    static func interpolate(at t: TimeInterval,
                            samples: [TimedPoint],
                            mode: InterpMode = .linear) -> (x: Double, y: Double)? {
        guard !samples.isEmpty else { return nil }
        if t <= samples.first!.t {
            return (samples.first!.x, samples.first!.y)
        }
        if t >= samples.last!.t {
            return (samples.last!.x, samples.last!.y)
        }
        // binary search to find pair t0<=t<=t1
        var low = 0
        var high = samples.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let tm = samples[mid].t
            if tm == t {
                return (samples[mid].x, samples[mid].y)
            } else if tm < t {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        let i1 = max(1, low)
        let i0 = i1 - 1
        let p0 = samples[i0]
        let p1 = samples[i1]
        let ratio = (t - p0.t) / (p1.t - p0.t)
        let x = p0.x + (p1.x - p0.x) * ratio
        let y = p0.y + (p1.y - p0.y) * ratio
        return (x, y)
    }
}

