import Foundation
@testable import PortMeKit

/// snapshot จำลองจากสิ่งที่เครื่องจริงคายออกมาตอนออกแบบ:
/// `next-server` ซ่อนอยู่ใต้ node สองชั้นเหนือ zsh และ monorepo หนึ่งตัวเปิดสอง port จาก bun ต้นเดียว
enum Fixtures {
    static let nodePath = "/Users/dev/.nvm/versions/node/v24.12.0/bin/node"
    static let bunPath = "/Users/dev/.bun/bin/bun"
    static let vsCodeHelperPath =
        "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper"
    static let figmaAgentPath =
        "/Users/dev/Library/Application Support/Figma/FigmaAgent.app/Contents/MacOS/figma_agent"
    static let controlCenterPath = "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"
    static let rapportdPath = "/usr/libexec/rapportd"

    /// launchd ← zsh ← node ← node ← next-server(:3000)
    /// launchd ← zsh ← bun ← bun ← { bun(:9001), node(:9000) }
    /// launchd ← Code Helper(:51659)   /   launchd ← rapportd(:54735)
    static let snapshot = ProcessSnapshot(
        processes: [
            .init(pid: 1, ppid: 0, executablePath: "/sbin/launchd"),
            .init(pid: 100, ppid: 1, executablePath: "/bin/zsh", workingDirectory: "/Users/dev"),
            .init(pid: 101, ppid: 100, executablePath: nodePath, workingDirectory: "/Users/dev/oss-portal"),
            .init(pid: 102, ppid: 101, executablePath: nodePath, workingDirectory: "/Users/dev/oss-portal"),
            .init(pid: 103, ppid: 102, executablePath: nodePath, workingDirectory: "/Users/dev/oss-portal"),
            .init(pid: 200, ppid: 1, executablePath: "/bin/zsh", workingDirectory: "/Users/dev"),
            .init(pid: 201, ppid: 200, executablePath: bunPath, workingDirectory: "/Users/dev/workspace-ui"),
            .init(pid: 202, ppid: 201, executablePath: bunPath, workingDirectory: "/Users/dev/workspace-ui"),
            .init(pid: 203, ppid: 202, executablePath: bunPath, workingDirectory: "/Users/dev/workspace-ui/server"),
            .init(pid: 204, ppid: 202, executablePath: nodePath, workingDirectory: "/Users/dev/workspace-ui/web"),
            .init(pid: 300, ppid: 1, executablePath: vsCodeHelperPath, workingDirectory: "/"),
            .init(pid: 400, ppid: 1, executablePath: rapportdPath, workingDirectory: "/"),
        ],
        listeners: [
            .init(pid: 103, port: 3000),
            .init(pid: 203, port: 9001),
            .init(pid: 204, port: 9000),
            .init(pid: 300, port: 51659),
            .init(pid: 400, port: 54735),
        ]
    )
}
