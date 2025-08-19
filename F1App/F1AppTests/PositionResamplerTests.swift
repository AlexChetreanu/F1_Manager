import XCTest
@testable import F1App

final class PositionResamplerTests: XCTestCase {
    func testLinearInterpolation() {
        let r = PositionResampler(stride: 0.2)
        let samples = [
            PositionSample(t: 0, x: 0, y: 0),
            PositionSample(t: 0.4, x: 4, y: 0)
        ]
        let out = r.resample(samples: samples)
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(out[1].x, 2, accuracy: 0.0001)
    }

    func testGapTeleport() {
        let r = PositionResampler(stride: 0.2)
        let samples = [
            PositionSample(t: 0, x: 0, y: 0),
            PositionSample(t: 1.5, x: 10, y: 0)
        ]
        let out = r.resample(samples: samples)
        XCTAssertEqual(out[1].x, 10, accuracy: 0.0001)
    }

    func testOutlierClamp() {
        let r = PositionResampler(stride: 0.2)
        let samples = [
            PositionSample(t: 0, x: 0, y: 0),
            PositionSample(t: 0.2, x: 1000, y: 0)
        ]
        let out = r.resample(samples: samples)
        XCTAssertEqual(out[1].x, 1000, accuracy: 0.0001)
    }
}
