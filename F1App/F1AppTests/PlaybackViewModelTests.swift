import XCTest
@testable import F1App

final class PlaybackViewModelTests: XCTestCase {
    func testTickAppliesOneEuro() {
        let vm = PlaybackViewModel()
        vm.isPlaying = true
        let fields = ["n", "x", "y"]
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 0.2)
        let d1: [[FrameDTO.FieldValue]] = [[
            .init(string: "1", double: nil),
            .init(string: nil, double: 0),
            .init(string: nil, double: 0)
        ]]
        let d2: [[FrameDTO.FieldValue]] = [[
            .init(string: "1", double: nil),
            .init(string: nil, double: 1),
            .init(string: nil, double: 0)
        ]]
        vm.buffer = [FrameDTO(t: t0, drivers: d1, fields: fields),
                     FrameDTO(t: t1, drivers: d2, fields: fields)]
        vm.tick()
        let x1 = vm.currentPositions.first?.x ?? 0
        vm.tick()
        let x2 = vm.currentPositions.first?.x ?? 0
        XCTAssertLessThan(abs(x2 - x1), 1.0)
    }
}
