import Foundation

/// snapshot คงที่สำหรับภาพ demo — ใช้ชื่อโปรเจกต์กับ port แบบที่เจอจริงตอนทำงาน
/// จะได้ไม่ต้องรอให้เครื่องบังเอิญมี dev server ค้างอยู่ตอนถ่ายรูป
struct DemoScanner: ProcessScanning {
    private static let node = "/Users/dev/.nvm/versions/node/v24.12.0/bin/node"
    private static let bun = "/Users/dev/.bun/bin/bun"
    private static let python = "/opt/homebrew/bin/python3"
    private static let orbstack = "/Applications/OrbStack.app/Contents/MacOS/OrbStack Helper"

    func scan() -> ProcessSnapshot {
        ProcessSnapshot(
            processes: [
                .init(pid: 1, ppid: 0, executablePath: "/sbin/launchd"),
                .init(pid: 100, ppid: 1, executablePath: "/bin/zsh", workingDirectory: "/Users/dev"),

                .init(pid: 101, ppid: 100, executablePath: Self.node, workingDirectory: "/Users/dev/oss-portal"),
                .init(pid: 102, ppid: 101, executablePath: "/Users/dev/oss-portal/node_modules/.bin/next-server",
                      workingDirectory: "/Users/dev/oss-portal"),

                .init(pid: 110, ppid: 100, executablePath: Self.bun, workingDirectory: "/Users/dev/workspace-ui"),
                .init(pid: 111, ppid: 110, executablePath: Self.bun, workingDirectory: "/Users/dev/workspace-ui/server"),
                .init(pid: 112, ppid: 110, executablePath: Self.node, workingDirectory: "/Users/dev/workspace-ui/web"),

                .init(pid: 120, ppid: 100, executablePath: "/Users/dev/marketing-site/node_modules/.bin/vite",
                      workingDirectory: "/Users/dev/marketing-site"),

                .init(pid: 130, ppid: 100, executablePath: Self.python, workingDirectory: "/Users/dev/ml-api"),

                .init(pid: 140, ppid: 1, executablePath: Self.orbstack, workingDirectory: "/"),
            ],
            listeners: [
                .init(pid: 102, port: 3000),
                .init(pid: 111, port: 9001),
                .init(pid: 112, port: 9000),
                .init(pid: 120, port: 5173),
                .init(pid: 130, port: 8000),
                .init(pid: 140, port: 3306),
            ]
        )
    }

    func isAlive(_ pid: pid_t) -> Bool { true }
}
