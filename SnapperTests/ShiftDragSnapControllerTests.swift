import CoreGraphics
import XCTest
@testable import Snapper

@MainActor
final class ShiftDragSnapControllerTests: XCTestCase {
    func testDragWithoutShiftDoesNotShowOverlayOrSnap() async {
        let harness = makeHarness()

        harness.controller.handle(.leftMouseDown(point: point(10, 90), shiftDown: false))
        harness.controller.handle(.leftMouseDragged(point: point(20, 80), shiftDown: false))
        harness.controller.handle(.leftMouseUp(point: point(20, 80), shiftDown: false))
        await Task.yield()

        XCTAssertEqual(harness.overlay.presentCount, 0)
        XCTAssertEqual(harness.windowManager.snappedZones.count, 0)
    }

    func testShiftDuringDragShowsOverlay() {
        let harness = makeHarness()

        harness.controller.handle(.leftMouseDown(point: point(10, 90), shiftDown: false))
        harness.controller.handle(.leftMouseDragged(point: point(20, 80), shiftDown: true))

        XCTAssertEqual(harness.overlay.presentCount, 1)
        XCTAssertEqual(harness.windowManager.capturedPoints, [CGPoint(x: 10, y: 90)])
    }

    func testShiftReleaseCancelsArmedSession() {
        let harness = makeHarness()

        harness.controller.handle(.leftMouseDown(point: point(10, 90), shiftDown: false))
        harness.controller.handle(.leftMouseDragged(point: point(20, 80), shiftDown: true))
        harness.controller.handle(.flagsChanged(point: point(20, 80), shiftDown: false))

        XCTAssertEqual(harness.overlay.dismissCount, 1)
        XCTAssertEqual(harness.windowManager.snappedZones.count, 0)
    }

    func testMouseUpOverHoveredZoneSnapsCapturedWindow() async {
        let harness = makeHarness()

        harness.controller.handle(.leftMouseDown(point: point(10, 90), shiftDown: true))
        harness.controller.handle(.leftMouseDragged(point: point(20, 80), shiftDown: true))
        harness.controller.handle(.leftMouseUp(point: point(30, 70), shiftDown: true))
        await Task.yield()

        XCTAssertEqual(harness.overlay.dismissCount, 1)
        XCTAssertEqual(harness.windowManager.snappedZones.map(\.id), [harness.zone.id])
    }

    func testMouseUpOutsideHoveredZoneCancels() async {
        let zone = SnapperZone(
            name: "Top Left",
            screenIndex: 0,
            screenDisplayID: 100,
            rect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        )
        let harness = makeHarness(zone: zone)

        harness.controller.handle(.leftMouseDown(point: point(10, 90), shiftDown: true))
        harness.controller.handle(.leftMouseDragged(point: point(20, 80), shiftDown: true))
        harness.controller.handle(.leftMouseUp(point: point(75, 25), shiftDown: true))
        await Task.yield()

        XCTAssertEqual(harness.overlay.dismissCount, 1)
        XCTAssertEqual(harness.windowManager.snappedZones.count, 0)
    }

    private func makeHarness(
        zone: SnapperZone = SnapperZone(
            name: "Full Screen",
            screenIndex: 0,
            screenDisplayID: 100,
            rect: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
    ) -> Harness {
        let monitor = FakeDragEventMonitor()
        let overlay = FakeSnapPreviewOverlayManager()
        let windowManager = FakeWindowManager()
        let accessibility = FakeAccessibilityManager()
        let controller = ShiftDragSnapController(
            eventMonitor: monitor,
            overlayManager: overlay,
            windowManager: windowManager,
            accessibilityManager: accessibility,
            dragThreshold: 5,
            hoverUpdateInterval: 0
        )
        let screen = ScreenDescriptor(
            index: 0,
            displayID: 100,
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            name: "Test Display",
            snapshot: nil
        )

        controller.start(context: ShiftDragSnapController.Context(
            zones: { [zone] },
            screens: { [screen] },
            isOnScreenEditorVisible: { false },
            showAccessibilityPrompt: {},
            showAlert: { _ in }
        ))

        return Harness(
            zone: zone,
            controller: controller,
            monitor: monitor,
            overlay: overlay,
            windowManager: windowManager,
            accessibility: accessibility
        )
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> GlobalDragPoint {
        GlobalDragPoint(appKit: CGPoint(x: x, y: y))
    }
}

@MainActor
private struct Harness {
    let zone: SnapperZone
    let controller: ShiftDragSnapController
    let monitor: FakeDragEventMonitor
    let overlay: FakeSnapPreviewOverlayManager
    let windowManager: FakeWindowManager
    let accessibility: FakeAccessibilityManager
}

private final class FakeDragEventMonitor: DragEventMonitoring {
    var onEvent: ((GlobalDragEvent) -> Void)?
    var didStart = false
    var didStop = false

    func start() -> Bool {
        didStart = true
        return true
    }

    func stop() {
        didStop = true
    }
}

@MainActor
private final class FakeSnapPreviewOverlayManager: SnapPreviewOverlayManaging {
    var presentCount = 0
    var updateCount = 0
    var dismissCount = 0
    var hoveredZoneIDs: [UUID?] = []

    func present(screens: [ScreenDescriptor], zones: [SnapperZone], hoveredZoneID: UUID?) {
        presentCount += 1
        hoveredZoneIDs.append(hoveredZoneID)
    }

    func update(screens: [ScreenDescriptor], zones: [SnapperZone], hoveredZoneID: UUID?) {
        updateCount += 1
        hoveredZoneIDs.append(hoveredZoneID)
    }

    func dismiss() {
        dismissCount += 1
    }
}

@MainActor
private final class FakeWindowManager: WindowCaptureSnapping {
    let capturedWindow = CapturedWindowToken.test()
    var capturedPoints: [CGPoint] = []
    var snappedZones: [SnapperZone] = []

    func captureWindow(at point: CGPoint) throws -> CapturedWindowToken {
        capturedPoints.append(point)
        return capturedWindow
    }

    func snapWindow(_ window: CapturedWindowToken, to zone: SnapperZone) throws {
        XCTAssertEqual(window, capturedWindow)
        snappedZones.append(zone)
    }
}

@MainActor
private final class FakeAccessibilityManager: AccessibilityChecking {
    var trusted = true

    func isTrusted() -> Bool {
        trusted
    }
}
