import AppKit
import Foundation

@MainActor
final class ShiftDragSnapController {
    struct Context {
        var zones: () -> [SnapperZone]
        var screens: () -> [ScreenDescriptor]
        var isOnScreenEditorVisible: () -> Bool
        var showAccessibilityPrompt: () -> Void
        var showAlert: (AppAlertMessage) -> Void
    }

    static let shared = ShiftDragSnapController(
        eventMonitor: GlobalDragEventMonitor.shared,
        overlayManager: ZoneSnapOverlayManager.shared,
        windowManager: WindowManager.shared,
        accessibilityManager: AccessibilityManager.shared
    )

    private enum State {
        case idle
        case mouseDown(startPoint: GlobalDragPoint)
        case dragging(startPoint: GlobalDragPoint, latestPoint: GlobalDragPoint)
        case armed(startPoint: GlobalDragPoint, latestPoint: GlobalDragPoint, window: CapturedWindowToken, hoveredZoneID: UUID?)
    }

    private let eventMonitor: DragEventMonitoring
    private let overlayManager: SnapPreviewOverlayManaging
    private let windowManager: WindowCaptureSnapping
    private let accessibilityManager: AccessibilityChecking
    private let hitTester: ZoneHitTester
    private let dragThreshold: CGFloat
    private let hoverUpdateInterval: TimeInterval

    private var context: Context?
    private var state: State = .idle
    private var lastHoverUpdate: Date = .distantPast
    private var lastMonitorWarning: Date = .distantPast

    init(
        eventMonitor: DragEventMonitoring,
        overlayManager: SnapPreviewOverlayManaging,
        windowManager: WindowCaptureSnapping,
        accessibilityManager: AccessibilityChecking,
        hitTester: ZoneHitTester = ZoneHitTester(),
        dragThreshold: CGFloat = 5,
        hoverUpdateInterval: TimeInterval = 1.0 / 60.0
    ) {
        self.eventMonitor = eventMonitor
        self.overlayManager = overlayManager
        self.windowManager = windowManager
        self.accessibilityManager = accessibilityManager
        self.hitTester = hitTester
        self.dragThreshold = dragThreshold
        self.hoverUpdateInterval = hoverUpdateInterval
    }

    func start(appState: AppState) {
        start(context: Context(
            zones: { [weak appState] in appState?.config.zones ?? [] },
            screens: { [weak appState] in appState?.screens ?? [] },
            isOnScreenEditorVisible: { [weak appState] in appState?.isOnScreenEditorVisible ?? false },
            showAccessibilityPrompt: { [weak appState] in
                appState?.showAccessibilityPrompt = true
            },
            showAlert: { [weak appState] alert in
                appState?.activeAlert = alert
            }
        ))
    }

    func start(context: Context) {
        self.context = context
        eventMonitor.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }

        guard eventMonitor.start() else {
            notifyMonitoringUnavailable("Snapper could not start global drag monitoring. Check Accessibility permissions and restart Snapper if Shift-drag snapping does not respond.")
            return
        }
    }

    func stop() {
        cancelActiveSession()
        eventMonitor.onEvent = nil
        eventMonitor.stop()
        context = nil
    }

    func cancelActiveSession() {
        overlayManager.dismiss()
        state = .idle
    }

    func handle(_ event: GlobalDragEvent) {
        switch event {
        case let .leftMouseDown(point, _):
            state = .mouseDown(startPoint: point)

        case let .leftMouseDragged(point, shiftDown):
            handleDrag(to: point, shiftDown: shiftDown)

        case let .leftMouseUp(point, shiftDown):
            handleMouseUp(at: point, shiftDown: shiftDown)

        case let .flagsChanged(point, shiftDown):
            handleFlagsChanged(at: point, shiftDown: shiftDown)

        case let .tapDisabled(message):
            notifyMonitoringUnavailable(message)
        }
    }

    private func handleDrag(to point: GlobalDragPoint, shiftDown: Bool) {
        switch state {
        case .idle:
            state = .dragging(startPoint: point, latestPoint: point)
            if shiftDown {
                tryArm(startPoint: point, currentPoint: point)
            }

        case let .mouseDown(startPoint):
            guard distance(from: startPoint.appKit, to: point.appKit) >= dragThreshold else {
                return
            }

            state = .dragging(startPoint: startPoint, latestPoint: point)
            if shiftDown {
                tryArm(startPoint: startPoint, currentPoint: point)
            }

        case let .dragging(startPoint, _):
            state = .dragging(startPoint: startPoint, latestPoint: point)
            if shiftDown {
                tryArm(startPoint: startPoint, currentPoint: point)
            }

        case let .armed(startPoint, _, window, hoveredZoneID):
            guard shiftDown else {
                cancelActiveSession()
                return
            }

            state = .armed(startPoint: startPoint, latestPoint: point, window: window, hoveredZoneID: hoveredZoneID)
            updateHover(at: point.appKit, force: false)
        }
    }

    private func handleFlagsChanged(at point: GlobalDragPoint, shiftDown: Bool) {
        switch state {
        case .idle:
            return

        case let .mouseDown(startPoint):
            if !shiftDown {
                return
            }

            if distance(from: startPoint.appKit, to: point.appKit) >= dragThreshold {
                state = .dragging(startPoint: startPoint, latestPoint: point)
                tryArm(startPoint: startPoint, currentPoint: point)
            }

        case let .dragging(startPoint, latestPoint):
            if shiftDown {
                tryArm(startPoint: startPoint, currentPoint: latestPoint)
            }

        case .armed:
            if !shiftDown {
                cancelActiveSession()
            }
        }
    }

    private func handleMouseUp(at point: GlobalDragPoint, shiftDown: Bool) {
        guard shiftDown else {
            cancelActiveSession()
            return
        }

        guard case let .armed(_, _, window, hoveredZoneID) = state else {
            state = .idle
            return
        }

        guard let context else {
            cancelActiveSession()
            return
        }

        updateHover(at: point.appKit, force: true)

        let latestHoveredZoneID: UUID?
        if case let .armed(_, _, _, updatedHoveredZoneID) = state {
            latestHoveredZoneID = updatedHoveredZoneID
        } else {
            latestHoveredZoneID = hoveredZoneID
        }

        guard let zoneID = latestHoveredZoneID,
              let zone = context.zones().first(where: { $0.id == zoneID })
        else {
            cancelActiveSession()
            return
        }

        overlayManager.dismiss()
        state = .idle

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try self.windowManager.snapWindow(window, to: zone)
            } catch {
                self.context?.showAlert(AppAlertMessage(
                    title: "Could Not Snap Window",
                    message: error.localizedDescription
                ))
            }
        }
    }

    private func tryArm(startPoint: GlobalDragPoint, currentPoint: GlobalDragPoint) {
        guard let context else {
            state = .idle
            return
        }

        guard !context.isOnScreenEditorVisible() else {
            cancelActiveSession()
            return
        }

        let zones = context.zones()
        let screens = context.screens()

        guard !zones.isEmpty, !screens.isEmpty else {
            state = .dragging(startPoint: startPoint, latestPoint: currentPoint)
            return
        }

        guard accessibilityManager.isTrusted() else {
            context.showAccessibilityPrompt()
            cancelActiveSession()
            return
        }

        do {
            let window = try windowManager.captureWindow(at: startPoint.accessibility)
            state = .armed(startPoint: startPoint, latestPoint: currentPoint, window: window, hoveredZoneID: nil)
            overlayManager.present(screens: screens, zones: zones, hoveredZoneID: nil)
            updateHover(at: currentPoint.appKit, force: true)
        } catch {
            cancelActiveSession()
        }
    }

    private func updateHover(at point: CGPoint, force: Bool) {
        guard let context else {
            return
        }

        guard case let .armed(startPoint, latestPoint, window, currentHoveredZoneID) = state else {
            return
        }

        let now = Date()
        guard force || now.timeIntervalSince(lastHoverUpdate) >= hoverUpdateInterval else {
            return
        }
        lastHoverUpdate = now

        let zones = context.zones()
        let screens = context.screens()
        let hoveredZoneID = hitTester
            .hoveredZone(at: point, zones: zones, screens: screens)?
            .id

        guard hoveredZoneID != currentHoveredZoneID || force else {
            return
        }

        state = .armed(startPoint: startPoint, latestPoint: latestPoint, window: window, hoveredZoneID: hoveredZoneID)
        overlayManager.update(screens: screens, zones: zones, hoveredZoneID: hoveredZoneID)
    }

    private func notifyMonitoringUnavailable(_ message: String) {
        guard Date().timeIntervalSince(lastMonitorWarning) > 30 else {
            return
        }

        lastMonitorWarning = Date()
        context?.showAlert(AppAlertMessage(
            title: "Shift-Drag Snapping Unavailable",
            message: message
        ))
    }

    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }
}
