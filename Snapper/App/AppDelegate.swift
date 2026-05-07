import AppKit
import Carbon

private let snapZoneHotKeyHandler: EventHandlerUPP = { _, eventRef, _ in
    guard let eventRef else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else {
        return status
    }

    HotKeyManager.shared.handleHotKeyEvent(id: hotKeyID.id)
    return noErr
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyEventHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else {
            return
        }

        installHotKeyHandlerIfNeeded()
        AppState.shared.finishLaunchSetup()
        ShiftDragSnapController.shared.start(appState: AppState.shared)
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !isRunningTests else {
            return
        }

        ShiftDragSnapController.shared.stop()
        ZoneSnapOverlayManager.shared.dismiss()
        OnScreenZoneEditorManager.shared.dismiss()
        HotKeyManager.shared.unregisterAll()
    }

    private func installHotKeyHandlerIfNeeded() {
        guard hotKeyEventHandlerRef == nil else {
            return
        }

        var eventTypeSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            snapZoneHotKeyHandler,
            1,
            &eventTypeSpec,
            nil,
            &hotKeyEventHandlerRef
        )

        if status != noErr {
            return
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
