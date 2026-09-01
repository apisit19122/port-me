import XCTest
@testable import PortMeKit

final class ProcessClassifierTests: XCTestCase {
    func testRuntimesInstalledByVersionManagersAreDev() {
        for path in [
            "/Users/dev/.nvm/versions/node/v24.12.0/bin/node",
            "/Users/dev/.bun/bin/bun",
            "/opt/homebrew/bin/node",
            "/Users/dev/.local/share/mise/installs/node/22/bin/node",
            "/usr/local/bin/deno",
        ] {
            XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: path), .dev, path)
        }
    }

    func testAppleShippedInterpretersInUsrBinAreDevNotSystem() {
        // `/usr/bin/python3 -m http.server` คือ dev server ที่ user เปิดเอง ไม่ใช่ daemon ของระบบ
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: "/usr/bin/python3"), .dev)
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: "/usr/bin/ruby"), .dev)
    }

    func testExecutablesInsideAppBundlesAreGUIApps() {
        for path in [
            "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper",
            "/Applications/OrbStack.app/Contents/Frameworks/OrbStack Helper.app/Contents/MacOS/OrbStack Helper",
            "/Applications/LINE.app/Contents/MacOS/LINE",
            // ไม่ได้อยู่ใน /Applications แต่ก็ยังเป็น .app bundle
            "/Users/dev/Library/Application Support/Figma/FigmaAgent.app/Contents/MacOS/figma_agent",
        ] {
            XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: path), .guiApp, path)
        }
    }

    func testSystemPathsAreSystemEvenWhenTheyAreAppBundles() {
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: Fixtures.controlCenterPath), .system)
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: "/usr/libexec/rapportd"), .system)
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: "/sbin/launchd"), .system)
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: "/usr/sbin/cupsd"), .system)
    }

    func testDirectoryNamedLikeAnAppDoesNotMakeAPlainBinaryAGUIApp() {
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: "/Users/dev/projects/myapp/server"), .dev)
    }

    func testInterpreterWrappedInAFrameworkIsDevNotAGUIApp() {
        // homebrew ห่อ python ไว้ใน Python.app ข้างใน Python.framework — เป็น runtime ไม่ใช่แอป
        let homebrewPython = "/opt/homebrew/Cellar/python@3.14/3.14.7/Frameworks/Python.framework"
            + "/Versions/3.14/Resources/Python.app/Contents/MacOS/Python"
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: homebrewPython), .dev)
    }

    func testHelperInsideAFrameworkThatIsItselfInsideAnAppIsStillAGUIApp() {
        // Chrome ซ้อน helper ไว้ใต้ framework แต่ framework นั้นอยู่ใน .app อีกที
        let chromeHelper = "/Applications/Google Chrome.app/Contents/Frameworks"
            + "/Google Chrome Framework.framework/Versions/120/Helpers"
            + "/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
        XCTAssertEqual(ProcessClassifier.kind(ofExecutableAt: chromeHelper), .guiApp)
    }

    func testShellsStopTheTreeWalkAndGUIAppsDoToo() {
        let shell = ProcessRecord(pid: 100, ppid: 1, executablePath: "/bin/zsh")
        let helper = ProcessRecord(pid: 300, ppid: 1, executablePath: Fixtures.vsCodeHelperPath)
        let node = ProcessRecord(pid: 101, ppid: 100, executablePath: Fixtures.nodePath)

        XCTAssertTrue(ProcessBarrier.stopsTreeWalk(shell))
        XCTAssertTrue(ProcessBarrier.stopsTreeWalk(helper))
        XCTAssertFalse(ProcessBarrier.stopsTreeWalk(node))
    }

    func testDescendantShellIsKillableEvenThoughItStopsTheTreeWalk() {
        let shell = ProcessRecord(pid: 100, ppid: 1, executablePath: "/bin/zsh")
        XCTAssertFalse(ProcessBarrier.isProtected(shell, protectedPIDs: []))
    }

    func testSystemProcessesAndOurOwnAncestorsAreNeverSignalled() {
        let daemon = ProcessRecord(pid: 400, ppid: 1, executablePath: Fixtures.rapportdPath)
        let ourShell = ProcessRecord(pid: 500, ppid: 1, executablePath: "/bin/zsh")

        XCTAssertTrue(ProcessBarrier.isProtected(daemon, protectedPIDs: []))
        XCTAssertTrue(ProcessBarrier.isProtected(ourShell, protectedPIDs: [500]))
    }
}
