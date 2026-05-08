import AppKit
import Foundation

final class UninstallManager {
    static let shared = UninstallManager()

    private init() {}

    func scheduleUninstall() throws {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL

        guard bundleURL.pathExtension == "app", bundleURL.lastPathComponent == "Snapper.app" else {
            throw UninstallError.unsupportedBundlePath(bundleURL.path)
        }

        let configurationURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Snapper", isDirectory: true)

        let script = """
        /bin/sleep 1
        /bin/rm -rf \(shellQuote(bundleURL.path))
        /bin/rm -rf \(shellQuote(configurationURL.path))
        /usr/bin/tccutil reset Accessibility com.snapper.app >/dev/null 2>&1 || true
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum UninstallError: LocalizedError {
    case unsupportedBundlePath(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedBundlePath(path):
            return "Snapper can only uninstall a running Snapper.app bundle. Current path: \(path)"
        }
    }
}
