import XCTest
@testable import F1App

final class PlaybackViewModelTests: XCTestCase {
    private func runTick(on vm: PlaybackViewModel) {
        vm.play()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        vm.pause()
    }

    func testTickConsumesSingleFrame() {
        let vm = PlaybackViewModel()
        vm.speed = 100
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

        runTick(on: vm)
        XCTAssertEqual(vm.buffer.count, 1)
        let x1 = vm.currentPositions.first?.x ?? 0

        runTick(on: vm)
        XCTAssertEqual(vm.buffer.count, 0)
        let x2 = vm.currentPositions.first?.x ?? 0
        XCTAssertNotEqual(x1, x2)
    }

    func testTickAppliesOneEuro() {
        let vm = PlaybackViewModel()
        vm.speed = 100
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

        runTick(on: vm)
        let x1 = vm.currentPositions.first?.x ?? 0
        runTick(on: vm)
        let x2 = vm.currentPositions.first?.x ?? 0
        XCTAssertLessThan(abs(x2 - x1), 1.0)
    }
}
