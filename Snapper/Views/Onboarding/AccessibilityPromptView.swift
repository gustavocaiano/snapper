import SwiftUI

struct AccessibilityPromptView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Accessibility Permission", systemImage: "hand.raised.fill")
                .font(.title3.weight(.semibold))

            Text("Snapper needs Accessibility access so it can move and resize the focused window when you trigger a snap shortcut.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("How to enable it")
                    .font(.subheadline.weight(.semibold))
                Text("1. Open System Settings")
                Text("2. Privacy & Security > Accessibility")
                Text("3. Enable Snapper and relaunch if prompted")
            }
            .font(.caption)

            HStack {
                Button("Open System Settings") {
                    appState.openAccessibilitySettings()
                }

                Button("Check Again") {
                    _ = appState.requestAccessibility(prompt: false)
                }

                Spacer()

                Button("Continue Without Access") {
                    appState.showAccessibilityPrompt = false
                }
            }
        }
        .padding(18)
        .frame(width: 520)
    }
}
