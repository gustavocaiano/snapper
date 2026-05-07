import CoreGraphics
import XCTest
@testable import Snapper

final class ZoneGeometryTests: XCTestCase {
    func testTargetWindowFramePreservesCurrentTopLeftNormalizedSemantics() {
        let screen = makeScreen(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        let zone = makeZone(rect: CGRect(x: 0, y: 0, width: 0.5, height: 0.25))

        XCTAssertEqual(
            ZoneGeometryMapper.targetWindowFrame(for: zone, in: screen),
            CGRect(x: 0, y: 600, width: 500, height: 200)
        )
    }

    func testTargetWindowFrameAppliesMinimumWindowSize() {
        let frame = ZoneGeometryMapper.targetWindowFrame(
            for: CGRect(x: 0.8, y: 0.8, width: 0.01, height: 0.01),
            in: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )

        XCTAssertEqual(frame.size, CGSize(width: 60, height: 60))
    }

    func testAccessibilityTopLeftPositionConvertsAppKitFrameOnMainDisplay() {
        let mainScreenFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let topLeftAppKitFrame = CGRect(x: 0, y: 600, width: 500, height: 200)
        let bottomLeftAppKitFrame = CGRect(x: 0, y: 0, width: 500, height: 200)

        XCTAssertEqual(
            ZoneGeometryMapper.accessibilityTopLeftPosition(
                forAppKitFrame: topLeftAppKitFrame,
                mainScreenFrame: mainScreenFrame
            ),
            CGPoint(x: 0, y: 0)
        )
        XCTAssertEqual(
            ZoneGeometryMapper.accessibilityTopLeftPosition(
                forAppKitFrame: bottomLeftAppKitFrame,
                mainScreenFrame: mainScreenFrame
            ),
            CGPoint(x: 0, y: 600)
        )
    }

    func testAccessibilityTopLeftPositionPreservesGlobalOffsetsAcrossDisplays() {
        let mainScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertEqual(
            ZoneGeometryMapper.accessibilityTopLeftPosition(
                forAppKitFrame: CGRect(x: 0, y: 900, width: 1440, height: 900),
                mainScreenFrame: mainScreenFrame
            ),
            CGPoint(x: 0, y: -900)
        )
        XCTAssertEqual(
            ZoneGeometryMapper.accessibilityTopLeftPosition(
                forAppKitFrame: CGRect(x: 0, y: -900, width: 1440, height: 900),
                mainScreenFrame: mainScreenFrame
            ),
            CGPoint(x: 0, y: 900)
        )
        XCTAssertEqual(
            ZoneGeometryMapper.accessibilityTopLeftPosition(
                forAppKitFrame: CGRect(x: -1280, y: 450, width: 640, height: 450),
                mainScreenFrame: mainScreenFrame
            ),
            CGPoint(x: -1280, y: 0)
        )
        XCTAssertEqual(
            ZoneGeometryMapper.accessibilityTopLeftPosition(
                forAppKitFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                mainScreenFrame: mainScreenFrame
            ),
            CGPoint(x: -1920, y: -180)
        )
    }

    func testHitTesterUsesDisplayIDBeforeScreenIndex() {
        let screens = [
            makeScreen(index: 0, displayID: 100, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
            makeScreen(index: 1, displayID: 200, frame: CGRect(x: 100, y: 0, width: 100, height: 100))
        ]
        let zone = makeZone(screenIndex: 0, screenDisplayID: 200, rect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))

        XCTAssertEqual(
            ZoneHitTester().hoveredZone(at: CGPoint(x: 125, y: 75), zones: [zone], screens: screens)?.id,
            zone.id
        )
        XCTAssertNil(
            ZoneHitTester().hoveredZone(at: CGPoint(x: 25, y: 75), zones: [zone], screens: screens)
        )
    }

    func testHitTesterFallsBackToScreenIndexWhenDisplayIDMissing() {
        let screens = [makeScreen(index: 1, displayID: 300, frame: CGRect(x: 0, y: 0, width: 100, height: 100))]
        let zone = makeZone(screenIndex: 1, screenDisplayID: nil, rect: CGRect(x: 0, y: 0, width: 1, height: 1))

        XCTAssertEqual(
            ZoneHitTester().hoveredZone(at: CGPoint(x: 50, y: 50), zones: [zone], screens: screens)?.id,
            zone.id
        )
    }

    func testHitTesterChoosesSmallestOverlappingZoneThenMostRecent() {
        let screen = makeScreen(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let large = makeZone(rect: CGRect(x: 0, y: 0, width: 1, height: 1))
        let small = makeZone(rect: CGRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4))
        let sameSizeEarlier = makeZone(rect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))
        let sameSizeLater = makeZone(rect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5))

        XCTAssertEqual(
            ZoneHitTester().hoveredZone(at: CGPoint(x: 30, y: 60), zones: [large, small], screens: [screen])?.id,
            small.id
        )
        XCTAssertEqual(
            ZoneHitTester().hoveredZone(at: CGPoint(x: 25, y: 75), zones: [sameSizeEarlier, sameSizeLater], screens: [screen])?.id,
            sameSizeLater.id
        )
    }

    func testHitTesterHandlesNegativeDisplayOrigins() {
        let screen = makeScreen(frame: CGRect(x: -800, y: 0, width: 800, height: 600))
        let zone = makeZone(rect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))

        XCTAssertEqual(
            ZoneHitTester().hoveredZone(at: CGPoint(x: -200, y: 150), zones: [zone], screens: [screen])?.id,
            zone.id
        )
        XCTAssertNil(
            ZoneHitTester().hoveredZone(at: CGPoint(x: -600, y: 450), zones: [zone], screens: [screen])
        )
    }

    private func makeScreen(
        index: Int = 0,
        displayID: UInt32 = 100,
        frame: CGRect
    ) -> ScreenDescriptor {
        ScreenDescriptor(
            index: index,
            displayID: displayID,
            frame: frame,
            visibleFrame: frame,
            name: "Display \(displayID)",
            snapshot: nil
        )
    }

    private func makeZone(
        screenIndex: Int = 0,
        screenDisplayID: UInt32? = 100,
        rect: CGRect
    ) -> SnapperZone {
        SnapperZone(
            name: UUID().uuidString,
            screenIndex: screenIndex,
            screenDisplayID: screenDisplayID,
            rect: rect
        )
    }
}
