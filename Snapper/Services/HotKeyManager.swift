import Carbon
import Foundation

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var eventRefs: [UInt32: EventHotKeyRef] = [:]
    private var zoneIDsByEventID: [UInt32: UUID] = [:]
    private var action: ((UUID) -> Void)?
    private var nextEventID: UInt32 = 1
    private let signature: OSType = HotKeyManager.fourCharCode("SNPZ")

    private init() {}

    func setAction(_ action: @escaping (UUID) -> Void) {
        self.action = action
    }

    func registerAll(zones: [SnapperZone]) -> [UUID: String] {
        unregisterAll()
        nextEventID = 1

        var issues: [UUID: String] = [:]
        var seenShortcuts: [HotKey: UUID] = [:]

        for zone in zones {
            guard let shortcut = zone.shortcut else {
                continue
            }

            if let duplicateZoneID = seenShortcuts[shortcut] {
                issues[zone.id] = "Shortcut conflicts with another Snapper zone (\(duplicateZoneID.uuidString.prefix(8)))."
                continue
            }
            seenShortcuts[shortcut] = zone.id

            let eventID = nextEventID
            let hotKeyID = EventHotKeyID(signature: signature, id: eventID)
            var eventRef: EventHotKeyRef?

            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &eventRef
            )

            if status == noErr, let eventRef {
                eventRefs[eventID] = eventRef
                zoneIDsByEventID[eventID] = zone.id
                nextEventID += 1
            } else {
                issues[zone.id] = registrationErrorMessage(status: status)
            }
        }

        return issues
    }

    func unregisterAll() {
        for eventRef in eventRefs.values {
            UnregisterEventHotKey(eventRef)
        }

        eventRefs.removeAll()
        zoneIDsByEventID.removeAll()
    }

    func handleHotKeyEvent(id: UInt32) {
        guard let zoneID = zoneIDsByEventID[id] else {
            return
        }

        action?(zoneID)
    }

    private func registrationErrorMessage(status: OSStatus) -> String {
        if status == eventHotKeyExistsErr {
            return "Shortcut conflicts with another app or existing global shortcut."
        }

        return "Could not register shortcut (error \(status))."
    }

    private static func fourCharCode(_ value: String) -> OSType {
        var result: UInt32 = 0
        for scalar in value.utf8.prefix(4) {
            result = (result << 8) + UInt32(scalar)
        }
        return result
    }
}
