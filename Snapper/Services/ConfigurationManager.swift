import Foundation

final class ConfigurationManager {
    static let shared = ConfigurationManager()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.snapper.config", qos: .utility)
    private let appSupportDirectoryName = "Snapper"
    private let legacyAppSupportDirectoryName = "SnapZone"

    private init() {}

    func load() -> AppConfig {
        do {
            let currentURL = try configURL(directoryName: appSupportDirectoryName)
            if fileManager.fileExists(atPath: currentURL.path) {
                let data = try Data(contentsOf: currentURL)
                return try JSONDecoder().decode(AppConfig.self, from: data)
            }

            let legacyURL = try configURL(directoryName: legacyAppSupportDirectoryName)
            if fileManager.fileExists(atPath: legacyURL.path) {
                let data = try Data(contentsOf: legacyURL)
                let legacyConfig = try JSONDecoder().decode(AppConfig.self, from: data)
                save(legacyConfig)
                return legacyConfig
            }

            return AppConfig()
        } catch {
            return AppConfig()
        }
    }

    func save(_ config: AppConfig) {
        let value = config

        queue.async {
            do {
                let url = try self.configURL(directoryName: self.appSupportDirectoryName)
                try self.ensureDirectoryExists(for: url)

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(value)
                try data.write(to: url, options: .atomic)
            } catch {
                return
            }
        }
    }

    private func configURL(directoryName: String) throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return appSupport
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    private func ensureDirectoryExists(for fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }
}
