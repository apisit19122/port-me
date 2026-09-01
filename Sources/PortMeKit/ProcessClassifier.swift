import Foundation

public enum ProcessKind: String, Sendable, CaseIterable {
    /// ของระบบ — ไม่แสดงและไม่ส่งสัญญาณ ไม่ว่าตั้งค่าอย่างไร
    case system
    /// แอป GUI — ซ่อนไว้จนกว่าจะเปิด Show all
    case guiApp
    /// process ที่ user เปิดเอง
    case dev
}

public enum ProcessClassifier {
    /// path ที่ macOS เป็นเจ้าของ — `/usr/bin` ไม่อยู่ในลิสต์โดยตั้งใจ เพราะ `/usr/bin/python3 -m http.server`
    /// คือ dev server ที่ user เปิดเอง ไม่ใช่ daemon ของระบบ
    static let systemPathPrefixes = [
        "/System/",
        "/usr/libexec/",
        "/usr/sbin/",
        "/sbin/",
        "/Library/Apple/",
    ]

    public static func kind(ofExecutableAt path: String) -> ProcessKind {
        if systemPathPrefixes.contains(where: path.hasPrefix) { return .system }
        if isInsideAppBundle(path) { return .guiApp }
        return .dev
    }

    /// จริงเมื่อ executable อยู่ใน `.app` ที่เป็นแอปให้คนเปิดจริง ๆ
    ///
    /// เทียบที่ `.app` นอกสุด แล้วดูว่ามี `.framework` มาก่อนหน้าไหม: homebrew ห่อ python ไว้ใน
    /// `Python.framework/.../Python.app` ซึ่งเป็น runtime ไม่ใช่แอป ส่วน helper ของ Chrome ที่อยู่ใน
    /// `Google Chrome.app/.../Google Chrome Framework.framework/...` มี `.app` มาก่อน จึงยังเป็นแอปอยู่
    static func isInsideAppBundle(_ path: String) -> Bool {
        let components = (path as NSString).deletingLastPathComponent.split(separator: "/")
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else { return false }
        return !components[..<appIndex].contains { $0.hasSuffix(".framework") }
    }
}

public enum ProcessBarrier {
    /// shell และ multiplexer ที่ dev tree ต้องหยุด ไม่งั้นจะไต่ขึ้นไปฆ่า terminal ของ user เอง
    static let shellNames: Set<String> = [
        "zsh", "bash", "sh", "fish", "dash", "ksh", "tcsh", "csh",
        "login", "tmux", "screen", "sshd", "launchd", "init",
    ]

    /// จริงเมื่อ dev tree ห้ามโตข้าม process นี้ตอนไต่ขึ้นหา root
    ///
    /// GUI app นับเป็นกำแพงด้วย เพื่อไม่ให้แถวของ Code Helper ไต่ขึ้นไปจนรากกลายเป็น
    /// ตัว VS Code เอง แล้วกด Kill ทีเดียวปิดทั้ง editor
    public static func stopsTreeWalk(_ record: ProcessRecord) -> Bool {
        if record.pid <= 1 { return true }
        if shellNames.contains(record.name) { return true }
        return record.kind != .dev
    }

    /// จริงเมื่อห้ามส่งสัญญาณไปที่ process นี้เด็ดขาด
    ///
    /// ต่างจาก `stopsTreeWalk`: shell ที่เป็นลูกหลานของ root ฆ่าได้ปกติ และ GUI app
    /// ที่เป็น root ของแถวที่ user กดเองก็ฆ่าได้ — ที่ห้ามคือของระบบกับตัวเราเอง
    public static func isProtected(_ record: ProcessRecord, protectedPIDs: Set<pid_t>) -> Bool {
        if record.pid <= 1 { return true }
        if protectedPIDs.contains(record.pid) { return true }
        return record.kind == .system
    }
}
