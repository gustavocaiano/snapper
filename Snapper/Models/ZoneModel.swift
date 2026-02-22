import CoreGraphics
import Foundation

struct SnapperZone: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var screenIndex: Int
    var rect: CGRect
    var shortcut: HotKey?

    init(
        id: UUID = UUID(),
        name: String,
        screenIndex: Int,
        rect: CGRect,
        shortcut: HotKey? = nil
    ) {
        self.id = id
        self.name = name
        self.screenIndex = screenIndex
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
    var launchAtLogin: Bool = false
    var hasPromptedLaunchAtLogin: Bool = false
    var hasSeenAccessibilityPrompt: Bool = false
}

struct AppAlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
