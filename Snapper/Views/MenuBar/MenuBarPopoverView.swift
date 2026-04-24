import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if appState.showLaunchAtLoginPrompt {
                launchPrompt
            }

            if !appState.accessibilityEnabled {
                accessibilityWarning
            }

            zoneList

            Button("Cycle Zones & Snap") {
                performSnapAction {
                    appState.cycleToNextZoneAndSnap()
                }
            }
            .disabled(appState.config.zones.isEmpty)

            HStack {
                Text("Cycle Shortcut")
                    .font(.subheadline)
                Spacer()
                ShortcutRecorderView(
                    value: appState.config.cycleShortcut,
                    onChange: appState.assignCycleShortcut
                )
            }

            if let warning = appState.cycleHotKeyRegistrationWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Button(appState.isOnScreenEditorVisible ? "Close On-Screen Editor" : "Edit Zones On Screen…") {
                let wasOnScreenEditorVisible = appState.isOnScreenEditorVisible
                appState.toggleOnScreenEditor()

                if !wasOnScreenEditorVisible {
                    dismiss()
                }
            }

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { appState.config.launchAtLogin },
                    set: { appState.setLaunchAtLogin($0) }
                )
            )

            Divider()

            Button("Quit Snapper") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 330)
        .sheet(isPresented: $appState.showAccessibilityPrompt) {
            AccessibilityPromptView()
                .environmentObject(appState)
        }
        .alert(item: $appState.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    private var header: some View {
        HStack {
            Label("Snapper", systemImage: "square.split.2x2")
                .font(.headline)
            Spacer()
            Text("\(appState.config.zones.count) zone\(appState.config.zones.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var zoneList: some View {
        Group {
            if appState.config.zones.isEmpty {
                Text("No zones configured yet. Click Edit Zones On Screen to create your first snap area.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(appState.config.zones) { zone in
                        Button {
                            performSnapAction {
                                appState.snap(zoneID: zone.id)
                            }
                        } label: {
                            HStack {
                                Text(zone.name)
                                    .lineLimit(1)
                                Spacer()
                                Text(zone.shortcut?.displayString ?? "No shortcut")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(zone.shortcut == nil ? .secondary : .primary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func performSnapAction(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            action()
        }
    }

    private var launchPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enable Launch at Login?")
                .font(.subheadline.weight(.semibold))
            Text("Start Snapper automatically when you sign in.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Not Now") {
                    appState.dismissLaunchAtLoginPrompt()
                }

                Button("Enable") {
                    appState.handleLaunchAtLoginPrompt(enable: true)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var accessibilityWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Accessibility access is required")
                .font(.caption.weight(.semibold))
            Text("Enable it to move and resize the focused window.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Settings") {
                    appState.openAccessibilitySettings()
                }
                Button("Check Again") {
                    _ = appState.requestAccessibility(prompt: false)
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
