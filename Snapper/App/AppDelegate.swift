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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyEventHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installHotKeyHandlerIfNeeded()
        AppState.shared.finishLaunchSetup()
    }

    func applicationWillTerminate(_ notification: Notification) {
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
}
