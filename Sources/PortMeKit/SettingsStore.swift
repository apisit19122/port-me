import Foundation

public final class SettingsStore: @unchecked Sendable {
    private enum Key {
        static let showAll = "showAllApps"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// default เป็น false — แอป GUI เป็น noise สำหรับงาน "dev server ค้าง"
    public var showAll: Bool {
        get { defaults.bool(forKey: Key.showAll) }
        set { defaults.set(newValue, forKey: Key.showAll) }
    }
}
