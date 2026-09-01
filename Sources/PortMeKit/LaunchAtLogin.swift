import ServiceManagement
import SwiftUI

public enum LaunchAtLogin {
    /// SMAppService ลงทะเบียนได้เฉพาะ `.app` bundle ที่มี bundle identifier
    /// ตอนรันจาก `swift run` ยังไม่มี bundle จึงใช้ไม่ได้
    public static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    public static var isEnabled: Bool {
        isAvailable && SMAppService.mainApp.status == .enabled
    }

    public static func set(_ enabled: Bool) throws {
        guard isAvailable else { return }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

struct LaunchAtLoginToggle: View {
    /// อ่านสถานะจริงจากระบบทุกครั้งที่แสดง เพราะ user เปลี่ยนได้เองใน System Settings
    @State private var isOn = LaunchAtLogin.isEnabled
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("เปิดเองตอน login", isOn: $isOn)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .disabled(!LaunchAtLogin.isAvailable)
                .onChange(of: isOn) { _, newValue in apply(newValue) }
            if !LaunchAtLogin.isAvailable {
                Text("ใช้ได้เมื่อรันจาก PortMe.app เท่านั้น")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else if let failure {
                Text(failure).font(.system(size: 10)).foregroundStyle(.red)
            }
        }
        .onAppear { isOn = LaunchAtLogin.isEnabled }
    }

    private func apply(_ newValue: Bool) {
        do {
            try LaunchAtLogin.set(newValue)
            failure = nil
        } catch {
            failure = "ตั้งค่าไม่สำเร็จ: \(error.localizedDescription)"
            // สะท้อนสถานะจริงกลับมา ไม่ให้ checkbox โกหกว่าเปิดได้แล้ว
            isOn = LaunchAtLogin.isEnabled
        }
    }
}
