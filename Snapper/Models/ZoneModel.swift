import CoreGraphics
import Foundation

struct SnapperZone: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var screenIndex: Int
    var screenDisplayID: UInt32?
    var rect: CGRect
    var shortcut: HotKey?

    init(
        id: UUID = UUID(),
        name: String,
        screenIndex: Int,
        screenDisplayID: UInt32? = nil,
        rect: CGRect,
        shortcut: HotKey? = nil
    ) {
        self.id = id
        self.name = name
        self.screenIndex = screenIndex
        self.screenDisplayID = screenDisplayID
        self.rect = rect.clampedUnitRect
        self.shortcut = shortcut
    }
}

struct HotKey: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
    var displayString: String
}

struct AppConfig: Codable, Equatable {
    var zones: [SnapperZone] = []
    var cycleShortcut: HotKey? = nil
    var launchAtLogin: Bool = false
    var hasPromptedLaunchAtLogin: Bool = false
    var hasSeenAccessibilityPrompt: Bool = false

    private enum CodingKeys: String, CodingKey {
        case zones
        case cycleShortcut
        case launchAtLogin
        case hasPromptedLaunchAtLogin
        case hasSeenAccessibilityPrompt
    }

    init(
        zones: [SnapperZone] = [],
        cycleShortcut: HotKey? = nil,
        launchAtLogin: Bool = false,
        hasPromptedLaunchAtLogin: Bool = false,
        hasSeenAccessibilityPrompt: Bool = false
    ) {
        self.zones = zones
        self.cycleShortcut = cycleShortcut
        self.launchAtLogin = launchAtLogin
        self.hasPromptedLaunchAtLogin = hasPromptedLaunchAtLogin
        self.hasSeenAccessibilityPrompt = hasSeenAccessibilityPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zones = try container.decodeIfPresent([SnapperZone].self, forKey: .zones) ?? []
        cycleShortcut = try container.decodeIfPresent(HotKey.self, forKey: .cycleShortcut)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hasPromptedLaunchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .hasPromptedLaunchAtLogin) ?? false
        hasSeenAccessibilityPrompt = try container.decodeIfPresent(Bool.self, forKey: .hasSeenAccessibilityPrompt) ?? false
    }
}

struct AppAlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
