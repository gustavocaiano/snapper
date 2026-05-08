import SwiftUI

@main
struct SnapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(appState)
        } label: {
            SnapperMarkView(size: 18, style: .menuBar)
                .accessibilityLabel("Snapper")
                .help("Snapper")
        }
        .menuBarExtraStyle(.window)
    }
}
