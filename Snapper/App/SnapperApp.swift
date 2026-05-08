import SwiftUI

@main
struct SnapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("Snapper", image: "MenuBarIconTemplate") {
            MenuBarPopoverView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
