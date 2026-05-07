import AppKit
import CoreGraphics

struct GlobalDragPoint: Equatable {
    let appKit: CGPoint
    let accessibility: CGPoint

    init(appKit: CGPoint, accessibility: CGPoint? = nil) {
        self.appKit = appKit
        self.accessibility = accessibility ?? appKit
    }
}

enum GlobalDragEvent: Equatable {
    case leftMouseDown(point: GlobalDragPoint, shiftDown: Bool)
    case leftMouseDragged(point: GlobalDragPoint, shiftDown: Bool)
    case leftMouseUp(point: GlobalDragPoint, shiftDown: Bool)
    case flagsChanged(point: GlobalDragPoint, shiftDown: Bool)
    case tapDisabled(String)
}

protocol DragEventMonitoring: AnyObject {
    var onEvent: ((GlobalDragEvent) -> Void)? { get set }

    func start() -> Bool
    func stop()
}

final class GlobalDragEventMonitor: DragEventMonitoring {
    static let shared = GlobalDragEventMonitor()

    var onEvent: ((GlobalDragEvent) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.eventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            return false
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard let dragEvent = dragEvent(from: type, event: event) else {
            return
        }

        Task { @MainActor in
            self.onEvent?(dragEvent)
        }
    }

    private func handleTapDisabled(type: CGEventType) {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }

        let reason = type == .tapDisabledByTimeout ? "The global drag monitor timed out and was re-enabled." : "The global drag monitor was disabled and Snapper attempted to re-enable it."
        Task { @MainActor in
            self.onEvent?(.tapDisabled(reason))
        }
    }

    private func dragEvent(from type: CGEventType, event: CGEvent) -> GlobalDragEvent? {
        let rawPoint = event.location
        let point = GlobalDragPoint(
            appKit: Self.appKitPoint(fromQuartzPoint: rawPoint),
            accessibility: rawPoint
        )
        let shiftDown = event.flags.contains(.maskShift)

        switch type {
        case .leftMouseDown:
            return .leftMouseDown(point: point, shiftDown: shiftDown)
        case .leftMouseDragged:
            return .leftMouseDragged(point: point, shiftDown: shiftDown)
        case .leftMouseUp:
            return .leftMouseUp(point: point, shiftDown: shiftDown)
        case .flagsChanged:
            return .flagsChanged(point: point, shiftDown: shiftDown)
        default:
            return nil
        }
    }

    private static let eventMask: CGEventMask = [
        CGEventType.leftMouseDown,
        .leftMouseDragged,
        .leftMouseUp,
        .flagsChanged
    ].reduce(CGEventMask(0)) { mask, type in
        mask | (CGEventMask(1) << CGEventMask(type.rawValue))
    }

    private static func appKitPoint(fromQuartzPoint point: CGPoint) -> CGPoint {
        guard let primaryFrame = NSScreen.screens.first(where: { $0.displayID == CGMainDisplayID() })?.frame
            ?? NSScreen.screens.first?.frame
        else {
            return point
        }

        return CGPoint(x: point.x, y: primaryFrame.maxY - point.y)
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<GlobalDragEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            monitor.handleTapDisabled(type: type)
            return Unmanaged.passUnretained(event)
        }

        monitor.handle(type: type, event: event)
        return Unmanaged.passUnretained(event)
    }
}
