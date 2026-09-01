import AppKit

public enum PortMeApp {
    @MainActor private static var delegate: AppDelegate?

    public static func run() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            Self.delegate = delegate
            app.delegate = delegate
            // .accessory = อยู่บน menu bar อย่างเดียว ไม่มีไอคอนใน Dock
            app.setActivationPolicy(.accessory)
            app.run()
        }
    }
}
