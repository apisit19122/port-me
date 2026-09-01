import Darwin
import XCTest
@testable import PortMeKit

/// ฆ่า process จริงที่ถือ port จริง — พิสูจน์ว่า `pnpm dev` ที่ spawn ลูกไปถือ port ไม่มีตัวไหนรอด
///
/// สร้าง DevServer เองแทนที่จะให้ DevServerBuilder หาราก เพราะสิ่งที่กำลังทดสอบคือ kill engine
/// ส่วนการไต่หารากมีเทสต์ของตัวเองอยู่แล้ว
final class ProcessKillerIntegrationTests: XCTestCase {
    private var harness: SpawnedTree?

    override func tearDown() {
        harness?.forceCleanup()
        harness = nil
        super.tearDown()
    }

    func testKillingTheTreeTakesDownBothTheParentAndTheListeningChild() async throws {
        let tree = try startTree(stubborn: false)
        let scanner = LibprocScanner()

        let report = await ProcessKiller().kill(tree.server, in: scanner.scan())

        XCTAssertTrue(report.succeeded, "ยังมี process รอด: \(report.survivingPIDs)")
        XCTAssertEqual(Set(report.targetedPIDs), [tree.parentPID, tree.childPID])
        XCTAssertFalse(scanner.isAlive(tree.parentPID), "process แม่ต้องตาย")
        XCTAssertFalse(scanner.isAlive(tree.childPID), "process ลูกที่ถือ port ต้องตาย")
    }

    func testPortIsFreeAfterTheKill() async throws {
        let tree = try startTree(stubborn: false)
        let scanner = LibprocScanner()

        _ = await ProcessKiller().kill(tree.server, in: scanner.scan())

        XCTAssertFalse(scanner.scan().listeners.contains { $0.port == tree.port })
    }

    func testTreeThatExitsOnSIGTERMIsNeverEscalated() async throws {
        let tree = try startTree(stubborn: false)

        let report = await ProcessKiller().kill(tree.server, in: LibprocScanner().scan())

        XCTAssertFalse(report.escalated)
    }

    func testChildIgnoringSIGTERMIsSIGKILLedAndReleasesThePort() async throws {
        let tree = try startTree(stubborn: true)
        let scanner = LibprocScanner()
        let killer = ProcessKiller(gracePeriod: .seconds(1))

        let report = await killer.kill(tree.server, in: scanner.scan())

        XCTAssertTrue(report.escalated, "ลูกที่ไม่สนใจ SIGTERM ต้องถูกยกระดับเป็น SIGKILL")
        XCTAssertTrue(report.succeeded, "ยังมี process รอด: \(report.survivingPIDs)")
        XCTAssertFalse(scanner.scan().listeners.contains { $0.port == tree.port })
    }

    /// เส้นทางเดียวกับที่แอปใช้จริง: สแกนของจริง หาต้นตอเอง แล้วฆ่าผ่าน model
    @MainActor
    func testTheAppFindsARealTreeAndKillsItThroughTheSameCodePathAsTheUI() async throws {
        let tree = try startTree(stubborn: true)
        let model = PortMeModel(
            killer: ProcessKiller(gracePeriod: .seconds(1)),
            settings: SettingsStore(defaults: UserDefaults(suiteName: "portme.e2e.\(UUID().uuidString)")!)
        )
        model.refresh()

        let row = try XCTUnwrap(
            model.visibleServers.first { $0.ports.contains(tree.port) },
            "แอปต้องเห็น dev server ที่เพิ่งเปิดบน port \(tree.port)"
        )
        // ไต่หาต้นตอเองได้ถูกตัว ไม่ใช่แค่ตัวที่ถือ port
        XCTAssertEqual(row.rootPID, tree.parentPID)

        await model.kill(row)

        XCTAssertFalse(model.visibleServers.contains { $0.ports.contains(tree.port) })
        XCTAssertEqual(model.status, "ต้องใช้ SIGKILL กับ 1 รายการ")
        XCTAssertFalse(LibprocScanner().isAlive(tree.parentPID))
    }

    // MARK: - harness

    private func startTree(stubborn: Bool) throws -> SpawnedTree {
        let tree = try SpawnedTree(stubborn: stubborn)
        harness = tree
        return tree
    }
}

/// process แม่ที่ spawn ลูกไปถือ port — เลียนแบบ `pnpm dev` ที่ตัวถือ port จริงเป็นลูก
private final class SpawnedTree {
    let parentPID: pid_t
    let childPID: pid_t
    let port: UInt16

    private let process: Process
    private let scriptURL: URL

    var server: DevServer {
        DevServer(
            rootPID: parentPID,
            listenerPIDs: [childPID],
            name: "python3",
            ports: [port],
            workingDirectory: nil,
            kind: .dev
        )
    }

    init(stubborn: Bool) throws {
        scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("portme-tree-\(UUID().uuidString).py")
        try Self.script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let output = Pipe()
        process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptURL.path, "parent", stubborn ? "stubborn" : "graceful"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw XCTSkip("ต้องมี python3 ถึงจะรันเทสต์นี้ได้: \(error)")
        }
        parentPID = process.processIdentifier

        port = try Self.readPort(from: output, deadline: .now() + 15)
        childPID = try Self.findListener(on: port, deadline: .now() + 5)
    }

    func forceCleanup() {
        for pid in [childPID, parentPID] { kill(pid, SIGKILL) }
        try? FileManager.default.removeItem(at: scriptURL)
    }

    private static func readPort(from pipe: Pipe, deadline: DispatchTime) throws -> UInt16 {
        var buffer = ""
        while DispatchTime.now() < deadline {
            let chunk = pipe.fileHandleForReading.availableData
            guard !chunk.isEmpty else { continue }
            buffer += String(decoding: chunk, as: UTF8.self)
            if let line = buffer.split(separator: "\n").first, let port = UInt16(line.trimmingCharacters(in: .whitespaces)) {
                return port
            }
        }
        throw Failure.noPortReported
    }

    private static func findListener(on port: UInt16, deadline: DispatchTime) throws -> pid_t {
        let scanner = LibprocScanner()
        while DispatchTime.now() < deadline {
            if let socket = scanner.scan().listeners.first(where: { $0.port == port }) { return socket.pid }
            usleep(50_000)
        }
        throw Failure.listenerNotFound(port)
    }

    enum Failure: Error {
        case noPortReported
        case listenerNotFound(UInt16)
    }

    /// แม่ spawn ลูกแล้วรอเฉย ๆ ลูกจอง port แล้วพิมพ์เลข port ออก stdout ที่สืบทอดมาจากแม่
    private static let script = """
    import signal, socket, subprocess, sys, time

    if sys.argv[1] == "parent":
        subprocess.Popen([sys.executable, __file__, "child", sys.argv[2]])
        time.sleep(120)
    else:
        if sys.argv[2] == "stubborn":
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
        server = socket.socket()
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        print(server.getsockname()[1], flush=True)
        time.sleep(120)
    """
}
