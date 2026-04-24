import Carbon
import Foundation

final class HotKeyManager {
    static let shared = HotKeyManager()

    private enum HotKeyAction {
        case zone(UUID)
        case cycle
    }

    private var eventRefs: [UInt32: EventHotKeyRef] = [:]
    private var actionsByEventID: [UInt32: HotKeyAction] = [:]
    private var zoneAction: ((UUID) -> Void)?
    private var cycleAction: (() -> Void)?
    private var nextEventID: UInt32 = 1
    private let signature: OSType = HotKeyManager.fourCharCode("SNPZ")

    private init() {}

    func setAction(_ action: @escaping (UUID) -> Void) {
        zoneAction = action
    }

    func setCycleAction(_ action: @escaping () -> Void) {
        cycleAction = action
    }

    func registerAll(zones: [SnapperZone]) -> [UUID: String] {
        registerAll(zones: zones, cycleShortcut: nil).zoneWarnings
    }

    func registerAll(zones: [SnapperZone], cycleShortcut: HotKey?) -> (zoneWarnings: [UUID: String], cycleWarning: String?) {
        unregisterAll()
        nextEventID = 1

        var zoneWarnings: [UUID: String] = [:]
        var cycleWarning: String?
        var seenShortcuts: [HotKey: UUID] = [:]
        var cycleConflictZoneID: UUID?

        for zone in zones {
            guard let shortcut = zone.shortcut else {
                continue
            }

            if let duplicateZoneID = seenShortcuts[shortcut] {
                zoneWarnings[zone.id] = "Shortcut conflicts with another Snapper zone (\(duplicateZoneID.uuidString.prefix(8)))."
                continue
            }

            if shortcut == cycleShortcut {
                zoneWarnings[zone.id] = "Shortcut conflicts with the cycle shortcut."
                if cycleConflictZoneID == nil {
                    cycleConflictZoneID = zone.id
                }
                continue
            }

            seenShortcuts[shortcut] = zone.id

            let registrationWarning = registerShortcut(shortcut, action: .zone(zone.id))
            if let registrationWarning {
                zoneWarnings[zone.id] = registrationWarning
            }
        }

        if let cycleShortcut {
            if let zoneID = cycleConflictZoneID ?? seenShortcuts[cycleShortcut] {
                cycleWarning = "Cycle shortcut conflicts with Snapper zone (\(zoneID.uuidString.prefix(8)))."
            } else {
                let registrationWarning = registerShortcut(cycleShortcut, action: .cycle)
                if let registrationWarning {
                    cycleWarning = registrationWarning
                }
            }
        }

        return (zoneWarnings, cycleWarning)
    }

    private func registerShortcut(_ shortcut: HotKey, action: HotKeyAction) -> String? {
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
            actionsByEventID[eventID] = action
            nextEventID += 1
            return nil
        }

        return registrationErrorMessage(status: status)
    }

    func unregisterAll() {
        for eventRef in eventRefs.values {
            UnregisterEventHotKey(eventRef)
        }

        eventRefs.removeAll()
        actionsByEventID.removeAll()
    }

    func handleHotKeyEvent(id: UInt32) {
        guard let action = actionsByEventID[id] else {
            return
        }

        switch action {
        case .zone(let zoneID):
            zoneAction?(zoneID)
        case .cycle:
            cycleAction?()
        }
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
