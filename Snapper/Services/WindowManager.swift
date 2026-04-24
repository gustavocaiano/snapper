import AppKit
import ApplicationServices

enum WindowManagerError: LocalizedError {
    case accessibilityUnavailable
    case focusedApplicationUnavailable
    case focusedWindowUnavailable
    case invalidScreenIndex
    case targetDisplayUnavailable
    case cannotSetWindowPosition
    case cannotSetWindowSize

    var errorDescription: String? {
        switch self {
        case .accessibilityUnavailable:
            return "Accessibility access is required to move windows."
        case .focusedApplicationUnavailable:
            return "Snapper could not find the focused application."
        case .focusedWindowUnavailable:
            return "Snapper could not find a focused window to move."
        case .invalidScreenIndex:
            return "The target screen is no longer available."
        case .targetDisplayUnavailable:
            return "The zone's display is unavailable. Reconnect the display or reassign the zone to an available screen."
        case .cannotSetWindowPosition:
            return "Snapper could not update the window position."
        case .cannotSetWindowSize:
            return "Snapper could not update the window size."
        }
    }
}

final class WindowManager {
    static let shared = WindowManager()

    private init() {}

    func snapFocusedWindow(to zone: SnapperZone) throws {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        let screens = NSScreen.screens
        let screen: NSScreen

        if let displayID = zone.screenDisplayID {
            guard let matchedScreen = screens.first(where: { $0.displayID == displayID }) else {
                throw WindowManagerError.targetDisplayUnavailable
            }
            screen = matchedScreen
        } else {
            guard screens.indices.contains(zone.screenIndex) else {
                throw WindowManagerError.invalidScreenIndex
            }
            screen = screens[zone.screenIndex]
        }
        let targetFrame = targetWindowFrame(for: zone.rect.clampedUnitRect, in: screen.frame)

        let systemElement = AXUIElementCreateSystemWide()

        var focusedAppValue: CFTypeRef?
        let focusedAppStatus = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppValue
        )

        guard focusedAppStatus == .success, let focusedAppValue else {
            throw WindowManagerError.focusedApplicationUnavailable
        }
        let focusedApp = unsafeBitCast(focusedAppValue, to: AXUIElement.self)

        var focusedWindowValue: CFTypeRef?
        let focusedWindowStatus = AXUIElementCopyAttributeValue(
            focusedApp,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        guard focusedWindowStatus == .success, let focusedWindowValue else {
            throw WindowManagerError.focusedWindowUnavailable
        }
        let focusedWindow = unsafeBitCast(focusedWindowValue, to: AXUIElement.self)

        var position = CGPoint(x: targetFrame.minX, y: targetFrame.minY)
        var size = CGSize(width: targetFrame.width, height: targetFrame.height)

        guard
            let positionValue = AXValueCreate(.cgPoint, &position),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            throw WindowManagerError.cannotSetWindowSize
        }

        let sizeStatus = AXUIElementSetAttributeValue(
            focusedWindow,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard sizeStatus == .success else {
            throw WindowManagerError.cannotSetWindowSize
        }

        let positionStatus = AXUIElementSetAttributeValue(
            focusedWindow,
            kAXPositionAttribute as CFString,
            positionValue
        )

        guard positionStatus == .success else {
            throw WindowManagerError.cannotSetWindowPosition
        }
    }

    private func targetWindowFrame(for rect: CGRect, in visibleFrame: CGRect) -> CGRect {
        let x = visibleFrame.minX + (rect.minX * visibleFrame.width)
        let targetMinYNormalized = 1 - rect.minY - rect.height
        let y = visibleFrame.minY + (targetMinYNormalized * visibleFrame.height)
        let width = visibleFrame.width * rect.width
        let height = visibleFrame.height * rect.height

        let frame = CGRect(
            x: x,
            y: y,
            width: max(60, width),
            height: max(60, height)
        )

        return frame.integral
    }
}
