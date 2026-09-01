import XCTest
@testable import PortMeKit

/// ทดสอบกับ kernel จริง — ยืนยันว่า libproc ให้ข้อมูลที่ใช้ได้ ไม่ได้ยืนยันว่ามี dev server ตัวไหนรันอยู่
final class LibprocScannerTests: XCTestCase {
    private let scanner = LibprocScanner()

    func testScanSeesTheTestProcessItself() {
        let snapshot = scanner.scan()
        XCTAssertTrue(snapshot.processes.contains { $0.pid == getpid() })
    }

    func testEveryRecordHasAUsablePIDAndPath() {
        for record in scanner.scan().processes {
            XCTAssertGreaterThan(record.pid, 0)
            XCTAssertTrue(record.executablePath.hasPrefix("/"), record.executablePath)
        }
    }

    func testAPIDNeverReportsTheSamePortTwice() {
        let listeners = scanner.scan().listeners
        XCTAssertEqual(Set(listeners.map { "\($0.pid):\($0.port)" }).count, listeners.count)
    }

    func testScanOnlyReturnsProcessesOwnedByTheCurrentUser() {
        // uid ที่ไม่มีอยู่จริงต้องไม่เจออะไรเลย — พิสูจน์ว่าตัวกรอง uid ทำงาน ไม่ใช่ผ่านเพราะบังเอิญ
        XCTAssertTrue(LibprocScanner(uid: 65_500).scan().processes.isEmpty)
    }

    func testAFreshlyOpenedPortShowsUpAgainstTheCurrentProcess() throws {
        let listener = try TestListener()
        defer { listener.close() }

        let mine = scanner.scan().listeners.filter { $0.pid == getpid() }
        XCTAssertTrue(mine.contains { $0.port == listener.port }, "ควรเห็น port \(listener.port) ที่เพิ่งเปิด")
    }

    func testClosedPortDisappearsFromTheNextScan() throws {
        let listener = try TestListener()
        let port = listener.port
        listener.close()

        XCTAssertFalse(scanner.scan().listeners.contains { $0.pid == getpid() && $0.port == port })
    }

    func testIsAliveAgreesWithRealProcesses() {
        XCTAssertTrue(scanner.isAlive(getpid()))
        XCTAssertFalse(scanner.isAlive(999_999))
    }
}
