import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var config: AppConfig {
        didSet {
            configurationManager.save(config)

            if oldValue.launchAtLogin != config.launchAtLogin {
                syncLaunchAtLoginState()
            }

            hotKeyRegistrationWarnings = hotKeyManager.registerAll(zones: config.zones)
        }
    }

    @Published private(set) var screens: [ScreenDescriptor] = []
    @Published var selectedZoneID: UUID?
    @Published var activeAlert: AppAlertMessage?
    @Published var hotKeyRegistrationWarnings: [UUID: String] = [:]
    @Published var showAccessibilityPrompt: Bool = false
    @Published var showLaunchAtLoginPrompt: Bool = false
    @Published private(set) var accessibilityEnabled: Bool = false
    @Published private(set) var isOnScreenEditorVisible: Bool = false
    @Published var isZoneCreateMode: Bool = false

    private let configurationManager = ConfigurationManager.shared
    private let hotKeyManager = HotKeyManager.shared
    private let windowManager = WindowManager.shared
    private let accessibilityManager = AccessibilityManager.shared
    private let screenManager = ScreenManager.shared
    private let loginItemManager = LoginItemManager.shared
    private let onScreenZoneEditorManager = OnScreenZoneEditorManager.shared

    private var hasCompletedLaunchSetup = false

    private init() {
        config = configurationManager.load()
        accessibilityEnabled = accessibilityManager.isTrusted()
        showAccessibilityPrompt = !accessibilityEnabled
        showLaunchAtLoginPrompt = !config.hasPromptedLaunchAtLogin

        hotKeyManager.setAction { [weak self] zoneID in
            Task { @MainActor in
                self?.snap(zoneID: zoneID)
            }
        }

        screenManager.onScreensChanged = { [weak self] in
            Task { @MainActor in
                self?.reloadScreens()
            }
        }

        reloadScreens()
        reconcileZoneScreenIndexesIfNeeded()
    }

    func finishLaunchSetup() {
        guard !hasCompletedLaunchSetup else {
            return
        }
        hasCompletedLaunchSetup = true

        hotKeyRegistrationWarnings = hotKeyManager.registerAll(zones: config.zones)

        if !config.hasSeenAccessibilityPrompt {
            _ = requestAccessibility(prompt: true)
            config.hasSeenAccessibilityPrompt = true
        }

        syncLaunchAtLoginState()
    }

    func reloadScreens() {
        screens = screenManager.currentScreens()
        reconcileZoneScreenIndexesIfNeeded()

        if isOnScreenEditorVisible {
            onScreenZoneEditorManager.present(appState: self, screens: screens)
        }
    }

    func toggleOnScreenEditor() {
        if isOnScreenEditorVisible {
            closeOnScreenEditor()
        } else {
            openOnScreenEditor()
        }
    }

    func openOnScreenEditor() {
        guard !isOnScreenEditorVisible else {
            return
        }

        isOnScreenEditorVisible = true
        isZoneCreateMode = true
        reloadScreens()
    }

    func closeOnScreenEditor() {
        guard isOnScreenEditorVisible else {
            return
        }

        onScreenZoneEditorManager.dismiss()
        isOnScreenEditorVisible = false
        isZoneCreateMode = false
    }

    func requestAccessibility(prompt: Bool) -> Bool {
        let trusted = accessibilityManager.requestTrust(prompt: prompt)
        accessibilityEnabled = trusted
        showAccessibilityPrompt = !trusted
        return trusted
    }

    func openAccessibilitySettings() {
        accessibilityManager.openPrivacySettings()
    }

    func handleLaunchAtLoginPrompt(enable: Bool) {
        var updated = config
        updated.hasPromptedLaunchAtLogin = true
        updated.launchAtLogin = enable
        config = updated
        showLaunchAtLoginPrompt = false
    }

    func dismissLaunchAtLoginPrompt() {
        var updated = config
        updated.hasPromptedLaunchAtLogin = true
        config = updated
        showLaunchAtLoginPrompt = false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        var updated = config
        updated.launchAtLogin = enabled
        config = updated
    }

    func addZone(on screenIndex: Int, normalizedRect: CGRect) {
        guard screens.indices.contains(screenIndex) else {
            return
        }

        let zone = SnapperZone(
            name: nextZoneName(),
            screenIndex: screenIndex,
            rect: normalizedRect.clampedUnitRect
        )

        config.zones.append(zone)
        selectedZoneID = zone.id
    }

    func addCenteredZone(on preferredScreen: Int? = nil) {
        guard !screens.isEmpty else {
            return
        }

        let inferredScreen = selectedZoneID
            .flatMap { id in config.zones.first(where: { $0.id == id })?.screenIndex }
            ?? 0

        let targetScreen = preferredScreen ?? inferredScreen

        addZone(
            on: targetScreen.clamped(to: 0 ... max(0, screens.count - 1)),
            normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        )
    }

    func removeZone(id: UUID) {
        config.zones.removeAll { $0.id == id }
        if selectedZoneID == id {
            selectedZoneID = config.zones.first?.id
        }
    }

    func assignShortcut(_ shortcut: HotKey?, to zoneID: UUID) {
        guard let index = config.zones.firstIndex(where: { $0.id == zoneID }) else {
            return
        }

        if let shortcut,
           let conflictingZone = config.zones.first(where: { $0.id != zoneID && $0.shortcut == shortcut }) {
            activeAlert = AppAlertMessage(
                title: "Shortcut Conflict",
                message: "\(conflictingZone.name) already uses \(shortcut.displayString)."
            )
            return
        }

        config.zones[index].shortcut = shortcut
    }

    func registrationWarning(for zoneID: UUID) -> String? {
        hotKeyRegistrationWarnings[zoneID]
    }

    func snap(zoneID: UUID) {
        guard let zone = config.zones.first(where: { $0.id == zoneID }) else {
            return
        }

        let trustedNow = accessibilityManager.isTrusted()
        accessibilityEnabled = trustedNow

        guard trustedNow else {
            showAccessibilityPrompt = true
            activeAlert = AppAlertMessage(
                title: "Accessibility Required",
                message: "Enable Accessibility access to move and resize windows."
            )
            return
        }

        do {
            try windowManager.snapFocusedWindow(to: zone)
        } catch {
            activeAlert = AppAlertMessage(
                title: "Could Not Snap Window",
                message: error.localizedDescription
            )
        }
    }

    private func reconcileZoneScreenIndexesIfNeeded() {
        guard !screens.isEmpty else {
            return
        }

        let upperBound = screens.count - 1
        var updated = config
        var didChange = false

        for index in updated.zones.indices {
            let current = updated.zones[index].screenIndex
            let clamped = current.clamped(to: 0 ... upperBound)
            if current != clamped {
                updated.zones[index].screenIndex = clamped
                didChange = true
            }
        }

        if didChange {
            config = updated
        }
    }

    private func nextZoneName() -> String {
        let existing = Set(config.zones.map(\.name))
        var index = 1
        while existing.contains("Zone \(index)") {
            index += 1
        }
        return "Zone \(index)"
    }

    private func syncLaunchAtLoginState() {
        let desired = config.launchAtLogin
        if desired == loginItemManager.isEnabled {
            return
        }

        switch loginItemManager.setEnabled(desired) {
        case .success:
            return
        case let .failure(error):
            activeAlert = AppAlertMessage(
                title: "Launch at Login",
                message: "Could not update Launch at Login: \(error.localizedDescription)"
            )

            var updated = config
            updated.launchAtLogin = loginItemManager.isEnabled
            if updated != config {
                config = updated
            }
        }
    }
}
