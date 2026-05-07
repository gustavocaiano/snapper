import AppKit
import SwiftUI

@MainActor
protocol SnapPreviewOverlayManaging: AnyObject {
    func present(screens: [ScreenDescriptor], zones: [SnapperZone], hoveredZoneID: UUID?)
    func update(screens: [ScreenDescriptor], zones: [SnapperZone], hoveredZoneID: UUID?)
    func dismiss()
}

@MainActor
final class SnapPreviewOverlayState: ObservableObject {
    @Published var screens: [ScreenDescriptor] = []
    @Published var zones: [SnapperZone] = []
    @Published var hoveredZoneID: UUID?
}

@MainActor
final class ZoneSnapOverlayManager: SnapPreviewOverlayManaging {
    static let shared = ZoneSnapOverlayManager()

    private let overlayState = SnapPreviewOverlayState()
    private var overlayWindows: [CGDirectDisplayID: NSWindow] = [:]

    private init() {}

    func present(screens: [ScreenDescriptor], zones: [SnapperZone], hoveredZoneID: UUID?) {
        let mappedDisplayIDs = mappedZoneDisplayIDs(screens: screens, zones: zones)
        let currentDisplayIDs = Set(overlayWindows.keys)

        overlayState.screens = screens
        overlayState.zones = zones
        overlayState.hoveredZoneID = hoveredZoneID

        guard currentDisplayIDs != mappedDisplayIDs || overlayWindows.isEmpty else {
            return
        }

        dismiss()
        overlayState.screens = screens
        overlayState.zones = zones
        overlayState.hoveredZoneID = hoveredZoneID

        for screen in screens where mappedDisplayIDs.contains(screen.displayID) {
            guard let nsScreen = NSScreen.screens.first(where: { $0.displayID == screen.displayID }) else {
                continue
            }

            let window = NSWindow(
                contentRect: nsScreen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: nsScreen
            )

            window.setFrame(nsScreen.frame, display: true)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .popUpMenu
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true

            window.contentView = NSHostingView(
                rootView: SnapPreviewOverlayView(screen: screen, state: overlayState)
            )
            window.orderFrontRegardless()

            overlayWindows[screen.displayID] = window
        }
    }

    func update(screens: [ScreenDescriptor], zones: [SnapperZone], hoveredZoneID: UUID?) {
        let mappedDisplayIDs = mappedZoneDisplayIDs(screens: screens, zones: zones)
        if overlayWindows.isEmpty || Set(overlayWindows.keys) != mappedDisplayIDs {
            present(screens: screens, zones: zones, hoveredZoneID: hoveredZoneID)
            return
        }

        overlayState.screens = screens
        overlayState.zones = zones
        overlayState.hoveredZoneID = hoveredZoneID
    }

    func dismiss() {
        for window in overlayWindows.values {
            window.orderOut(nil)
            window.close()
        }

        overlayWindows.removeAll()
        overlayState.hoveredZoneID = nil
    }

    private func mappedZoneDisplayIDs(screens: [ScreenDescriptor], zones: [SnapperZone]) -> Set<CGDirectDisplayID> {
        Set(zones.compactMap { zone in
            ZoneGeometryMapper.screen(for: zone, in: screens)?.displayID
        })
    }
}
