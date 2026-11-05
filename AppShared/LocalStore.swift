import Foundation

enum LocalStore {
    private static let preferencesKey = "walkuno.preferences.v1"

    static var cacheURL: URL? {
        let manager = FileManager.default
        let group = Bundle.main.object(forInfoDictionaryKey: "WalkunoAppGroup") as? String ?? "group.fr.orbelio.walkuno"
        let directory = manager.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? manager.urls(for: .cachesDirectory, in: .userDomainMask).first
        return directory?.appendingPathComponent("activity-v1.json")
    }

    static func preferences() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(Preferences.self, from: data) else { return .init() }
        return preferences
    }

    static func save(_ preferences: Preferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: preferencesKey)
    }

    static func snapshot() -> WidgetSnapshot? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url), data.count <= 100_000 else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) throws {
        guard var url = cacheURL else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(snapshot).write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    static func clear() throws {
        if let url = cacheURL, FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: preferencesKey)
    }
}
