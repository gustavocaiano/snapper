import AppKit
import SwiftUI

@MainActor
final class OnScreenZoneEditorManager {
    static let shared = OnScreenZoneEditorManager()

    private var overlayWindows: [CGDirectDisplayID: NSWindow] = [:]

    private init() {}

    func present(appState: AppState, screens: [ScreenDescriptor]) {
        dismiss()

        let mainDisplayID = NSScreen.main?.displayID

        for screen in screens {
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
            window.ignoresMouseEvents = false
            window.level = .popUpMenu
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true

            let rootView = OnScreenZoneEditorView(
                screenIndex: screen.index,
                screenName: screen.name,
                showsInspector: mainDisplayID == nil ? screen.index == 0 : screen.displayID == mainDisplayID
            )
            .environmentObject(appState)

            window.contentView = NSHostingView(rootView: rootView)
            window.orderFrontRegardless()

            overlayWindows[screen.displayID] = window
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        for window in overlayWindows.values {
            window.orderOut(nil)
            window.close()
        }

        overlayWindows.removeAll()
    }
}
