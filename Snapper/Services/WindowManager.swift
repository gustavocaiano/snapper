import AppKit
import ApplicationServices

enum WindowManagerError: LocalizedError {
    case accessibilityUnavailable
    case focusedApplicationUnavailable
    case focusedWindowUnavailable
    case windowAtPointUnavailable
    case invalidWindow
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
        case .windowAtPointUnavailable:
            return "Snapper could not identify the dragged window."
        case .invalidWindow:
            return "The selected window cannot be moved or resized."
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

struct CapturedWindowToken: Equatable {
    let id: UUID
    fileprivate let element: AXUIElement?

    init(id: UUID = UUID(), element: AXUIElement?) {
        self.id = id
        self.element = element
    }

    static func test(id: UUID = UUID()) -> CapturedWindowToken {
        CapturedWindowToken(id: id, element: nil)
    }

    static func == (lhs: CapturedWindowToken, rhs: CapturedWindowToken) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
protocol WindowCaptureSnapping: AnyObject {
    func captureWindow(at point: CGPoint) throws -> CapturedWindowToken
    func snapWindow(_ window: CapturedWindowToken, to zone: SnapperZone) throws
}

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private init() {}

    func snapFocusedWindow(to zone: SnapperZone) throws {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        let focusedWindow = try focusedWindow()
        try snapWindow(focusedWindow, to: zone)
    }

    func snapFocusedWindow(ofApplicationWithProcessID processID: pid_t, to zone: SnapperZone) throws {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        let focusedWindow = try focusedWindow(forApplicationWithProcessID: processID)
        try snapWindow(focusedWindow, to: zone)
    }

    func captureWindow(at point: CGPoint) throws -> CapturedWindowToken {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        if let windowAtPoint = try window(at: point) {
            return windowAtPoint
        }

        throw WindowManagerError.windowAtPointUnavailable
    }

    func focusedWindow() throws -> CapturedWindowToken {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        let systemElement = AXUIElementCreateSystemWide()
        let focusedApp = try focusedApplication(from: systemElement)
        let focusedWindow = try copyAXElement(
            from: focusedApp,
            attribute: kAXFocusedWindowAttribute as CFString,
            error: WindowManagerError.focusedWindowUnavailable
        )

        guard isValidWindow(focusedWindow) else {
            throw WindowManagerError.invalidWindow
        }

        return CapturedWindowToken(element: focusedWindow)
    }

    func focusedWindow(forApplicationWithProcessID processID: pid_t) throws -> CapturedWindowToken {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        let applicationElement = AXUIElementCreateApplication(processID)

        if let focusedWindow = optionalAXElement(
            from: applicationElement,
            attribute: kAXFocusedWindowAttribute as CFString
        ), isValidWindow(focusedWindow) {
            return CapturedWindowToken(element: focusedWindow)
        }

        if let mainWindow = optionalAXElement(
            from: applicationElement,
            attribute: kAXMainWindowAttribute as CFString
        ), isValidWindow(mainWindow) {
            return CapturedWindowToken(element: mainWindow)
        }

        if let firstValidWindow = firstValidWindow(for: applicationElement) {
            return CapturedWindowToken(element: firstValidWindow)
        }

        throw WindowManagerError.focusedWindowUnavailable
    }

    func window(at point: CGPoint) throws -> CapturedWindowToken? {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        let systemElement = AXUIElementCreateSystemWide()
        var elementValue: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(
            systemElement,
            Float(point.x),
            Float(point.y),
            &elementValue
        )

        guard status == .success, let elementValue else {
            return nil
        }

        guard let window = containingWindow(for: elementValue), isValidWindow(window) else {
            return nil
        }

        return CapturedWindowToken(element: window)
    }

    func snapWindow(_ window: CapturedWindowToken, to zone: SnapperZone) throws {
        guard AccessibilityManager.shared.isTrusted() else {
            throw WindowManagerError.accessibilityUnavailable
        }

        guard let element = window.element else {
            throw WindowManagerError.invalidWindow
        }

        guard isValidWindow(element) else {
            throw WindowManagerError.invalidWindow
        }

        let screens = currentScreens()
        guard let screen = ZoneGeometryMapper.screen(
            for: zone,
            in: screens,
            allowScreenIndexFallbackForMissingDisplayID: false
        ) else {
            if zone.screenDisplayID != nil {
                throw WindowManagerError.targetDisplayUnavailable
            }

            throw WindowManagerError.invalidScreenIndex
        }

        let targetFrame = ZoneGeometryMapper.targetWindowFrame(for: zone, in: screen)
        let mainScreenFrame = screens.first(where: { $0.displayID == CGMainDisplayID() })?.frame
            ?? screens.first?.frame
            ?? screen.frame

        var position = ZoneGeometryMapper.accessibilityTopLeftPosition(
            forAppKitFrame: targetFrame,
            mainScreenFrame: mainScreenFrame
        )
        var size = CGSize(width: targetFrame.width, height: targetFrame.height)

        guard
            let positionValue = AXValueCreate(.cgPoint, &position),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            throw WindowManagerError.cannotSetWindowSize
        }

        let sizeStatus = AXUIElementSetAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard sizeStatus == .success else {
            throw WindowManagerError.cannotSetWindowSize
        }

        let positionStatus = AXUIElementSetAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            positionValue
        )

        guard positionStatus == .success else {
            throw WindowManagerError.cannotSetWindowPosition
        }

        let finalSizeStatus = AXUIElementSetAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard finalSizeStatus == .success else {
            throw WindowManagerError.cannotSetWindowSize
        }
    }

    private func focusedApplication(from systemElement: AXUIElement) throws -> AXUIElement {
        try copyAXElement(
            from: systemElement,
            attribute: kAXFocusedApplicationAttribute as CFString,
            error: WindowManagerError.focusedApplicationUnavailable
        )
    }

    private func copyAXElement(
        from element: AXUIElement,
        attribute: CFString,
        error: WindowManagerError
    ) throws -> AXUIElement {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard status == .success, let value else {
            throw error
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func optionalAXElement(from element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard status == .success, let value else {
            return nil
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func firstValidWindow(for applicationElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXWindowsAttribute as CFString,
            &value
        )

        guard status == .success, let windows = value as? [AXUIElement] else {
            return nil
        }

        return windows.first(where: isValidWindow)
    }

    private func containingWindow(for element: AXUIElement) -> AXUIElement? {
        var current = element

        for _ in 0 ..< 8 {
            if stringAttribute(kAXRoleAttribute as CFString, from: current) == kAXWindowRole as String {
                return current
            }

            var parentValue: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(
                current,
                kAXParentAttribute as CFString,
                &parentValue
            )

            guard status == .success, let parentValue else {
                return nil
            }

            current = unsafeBitCast(parentValue, to: AXUIElement.self)
        }

        return nil
    }

    private func isValidWindow(_ window: AXUIElement) -> Bool {
        guard stringAttribute(kAXRoleAttribute as CFString, from: window) == kAXWindowRole as String else {
            return false
        }

        if processID(for: window) == getpid() {
            return false
        }

        if boolAttribute(kAXMinimizedAttribute as CFString, from: window) == true {
            return false
        }

        guard isAttributeSettable(kAXPositionAttribute as CFString, for: window),
              isAttributeSettable(kAXSizeAttribute as CFString, for: window)
        else {
            return false
        }

        return true
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard status == .success, let value else {
            return nil
        }

        return value as? String
    }

    private func boolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard status == .success, let value else {
            return nil
        }

        return value as? Bool
    }

    private func processID(for element: AXUIElement) -> pid_t? {
        var pid = pid_t(0)
        let status = AXUIElementGetPid(element, &pid)
        return status == .success ? pid : nil
    }

    private func isAttributeSettable(_ attribute: CFString, for element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let status = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return status == .success && settable.boolValue
    }

    private func currentScreens() -> [ScreenDescriptor] {
        NSScreen.screens.enumerated().map { index, screen in
            ScreenDescriptor(
                index: index,
                displayID: screen.displayID,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                name: screen.localizedName,
                snapshot: nil
            )
        }
    }
}

extension WindowManager: WindowCaptureSnapping {}
