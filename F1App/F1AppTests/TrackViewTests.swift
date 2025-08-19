import XCTest
import SwiftUI
@testable import F1App

final class TrackViewTests: XCTestCase {
    func testPositionIsFinite() {
        let bounds = TrackView.TrackInfo.Bounds(minX: 0, minY: 0, maxX: 0, maxY: 0)
        let track = TrackView.TrackInfo(imageURL: nil, bounds: bounds)
        let driver = TrackView.DriverPos(id: "1", x: .infinity, y: .nan, color: .red)
        let view = TrackView(track: track, drivers: [driver])
        let p = view.position(for: driver, in: .init(width: 0, height: 0))
        XCTAssert(p.x.isFinite && p.y.isFinite)
    }

    func testNoExplicitAnimation() throws {
        let base = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let srcURL = base.appendingPathComponent("F1App/TrackView.swift")
        let src = try String(contentsOf: srcURL)
        XCTAssertFalse(src.contains(".animation("))
    }
}
