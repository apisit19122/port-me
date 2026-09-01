import AppKit
import SwiftUI

/// ถ่ายรูป popover ของจริงลงไฟล์เพื่อใช้ใน README
///
/// วาดจาก view hierarchy ตรง ๆ ด้วย `cacheDisplay` ไม่ได้จับภาพหน้าจอ จึงไม่ต้องขอสิทธิ์
/// Screen Recording และได้ปุ่มกับ checkbox ที่ AppKit วาดจริง ไม่ใช่ของที่วาดเลียนแบบ
public enum DemoShot {
    @MainActor
    public static func capture(to path: String) {
        let model = PortMeModel(scanner: DemoScanner(), settings: SettingsStore(defaults: demoDefaults()))
        model.refresh()

        guard let popover = render(PopoverView(model: model, onQuit: {})) else {
            print("เรนเดอร์ popover ไม่สำเร็จ")
            return
        }
        guard let composed = compose(popover) else {
            print("จัดวางภาพไม่สำเร็จ")
            return
        }
        write(composed, to: path)
    }

    /// UserDefaults แยกโดม เพื่อไม่ให้การถ่ายรูปไปทับค่าที่ user ตั้งไว้จริง
    private static func demoDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.oat.portme.demo") ?? .standard
    }

    @MainActor
    private static func render(_ view: some View) -> NSImage? {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .light))
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)

        // ต้องมีหน้าต่างจริงก่อน AppKit ถึงจะ layout แล้ววาด control ออกมาครบ
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        let image = NSImage(size: hosting.bounds.size)
        image.addRepresentation(rep)
        return image
    }
}
