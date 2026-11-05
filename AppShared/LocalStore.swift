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

    private static var proAccessURL: URL? {
        // A development override must never survive into an installed Release build.
        #if DEBUG
        let filename = "pro-access-debug-v1.json"
        #else
        let filename = "pro-access-v1.json"
        #endif
        return cacheURL?.deletingLastPathComponent().appendingPathComponent(filename)
    }

    static func proAccess() -> ProAccess {
        guard let url = proAccessURL,
              let data = try? Data(contentsOf: url), data.count < 4096,
              let access = try? JSONDecoder().decode(ProAccess.self, from: data) else { return .init() }
        return access
    }

    static func save(_ access: ProAccess) throws {
        guard var url = proAccessURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        try JSONEncoder().encode(access).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    static func preferences() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(Preferences.self, from: data) else { return .init() }
        return preferences
    }

    static func save(_ preferences: Preferences) {
        // Persistent UserDefaults are included in device backups (including iCloud).
        // Keep user choices here, separate from the disposable, backup-excluded widget cache.
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
}
