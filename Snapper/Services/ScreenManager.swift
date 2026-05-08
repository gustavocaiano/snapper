import AppKit
import CoreGraphics

struct ScreenDescriptor: Identifiable {
    let index: Int
    let displayID: CGDirectDisplayID
    let frame: CGRect
    let visibleFrame: CGRect
    let name: String
    let snapshot: CGImage?

    var id: Int { index }
}

final class ScreenManager {
    static let shared = ScreenManager()

    var onScreensChanged: (() -> Void)?

    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onScreensChanged?()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func currentScreens() -> [ScreenDescriptor] {
        NSScreen.screens.enumerated().map { index, screen in
            let displayID = screen.displayID
            return ScreenDescriptor(
                index: index,
                displayID: displayID,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                name: screen.localizedName,
                snapshot: snapshot(for: screen)
            )
        }
    }

    func boundingRect(for screens: [ScreenDescriptor]) -> CGRect {
        screens.reduce(CGRect.null) { partial, screen in
            partial.union(screen.frame)
        }
    }

    private func snapshot(for screen: NSScreen) -> CGImage? {
        guard
            let wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen),
            let image = NSImage(contentsOf: wallpaperURL),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        return cgImage
    }
}
