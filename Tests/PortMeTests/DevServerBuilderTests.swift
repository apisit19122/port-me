import XCTest
@testable import PortMeKit

final class DevServerBuilderTests: XCTestCase {
    private func build(_ snapshot: ProcessSnapshot = Fixtures.snapshot, protected: Set<pid_t> = []) -> [DevServer] {
        DevServerBuilder.build(from: snapshot, protectedPIDs: protected)
    }

    func testSystemDaemonsNeverBecomeARow() {
        XCTAssertFalse(build().contains { $0.ports.contains(54735) })
    }

    func testDevTreeRootIsTheProcessJustBelowTheShell() {
        let server = try? XCTUnwrap(build().first { $0.ports == [3000] })
        // listener คือ pid 103 แต่ node อีกสองตัวเหนือมันเป็นของงานเดียวกัน
        XCTAssertEqual(server?.rootPID, 101)
        XCTAssertEqual(server?.listenerPIDs, [103])
    }

    func testTwoListenersUnderOneCommandCollapseIntoOneRow() throws {
        let monorepo = try XCTUnwrap(build().first { $0.ports.contains(9000) })
        XCTAssertEqual(monorepo.ports, [9000, 9001])
        XCTAssertEqual(monorepo.rootPID, 201)
        XCTAssertEqual(Set(monorepo.listenerPIDs), [203, 204])
    }

    func testRowIsNamedAfterTheProcessesActuallyHoldingThePorts() throws {
        let monorepo = try XCTUnwrap(build().first { $0.ports.contains(9000) })
        // listener คือ bun กับ node ถึงแม้ root จะเป็น bun ตัวเดียว
        XCTAssertEqual(monorepo.name, "bun, node")
    }

    func testProjectFolderComesFromTheRootNotTheDeepestListener() throws {
        let monorepo = try XCTUnwrap(build().first { $0.ports.contains(9000) })
        // listener ลูก chdir ลงไปที่ server/ กับ web/ แล้ว แต่โปรเจกต์คือ workspace-ui
        XCTAssertEqual(monorepo.projectFolder, "workspace-ui")
    }

    func testGUIAppRowsAreBuiltButTaggedSoTheUICanHideThem() throws {
        let helper = try XCTUnwrap(build().first { $0.ports == [51659] })
        XCTAssertEqual(helper.kind, .guiApp)
        XCTAssertEqual(build().filter { $0.kind == .dev }.count, 2)
    }

    func testGUIAppRowDoesNotClimbIntoItsParentApplication() throws {
        let snapshot = ProcessSnapshot(
            processes: Fixtures.snapshot.processes + [
                .init(pid: 301, ppid: 300, executablePath: Fixtures.vsCodeHelperPath, workingDirectory: "/"),
            ],
            listeners: Fixtures.snapshot.listeners + [.init(pid: 301, port: 60000)]
        )
        let row = try XCTUnwrap(build(snapshot).first { $0.ports == [60000] })
        // ฆ่าแถวนี้ต้องไม่ปิดทั้ง editor
        XCTAssertEqual(row.rootPID, 301)
    }

    func testRowsAreOrderedByTheirLowestPort() {
        XCTAssertEqual(build().map { $0.ports.first }, [3000, 9000, 51659])
    }

    func testSamePortReportedOnIPv4AndIPv6IsCountedOnce() {
        let snapshot = ProcessSnapshot(
            processes: Fixtures.snapshot.processes,
            listeners: [.init(pid: 103, port: 3000), .init(pid: 103, port: 3000)]
        )
        XCTAssertEqual(build(snapshot).first?.ports, [3000])
    }

    func testTreeWalkStopsBeforeOurOwnAncestors() throws {
        // สมมติว่า Port me ถูกเปิดจาก node 101 เอง — ต้องไม่ไต่ขึ้นไปจนฆ่าตัวเอง
        let server = try XCTUnwrap(build(protected: [101]).first { $0.ports == [3000] })
        XCTAssertEqual(server.rootPID, 102)
    }

    func testEmptySnapshotProducesNoRows() {
        XCTAssertTrue(build(.empty).isEmpty)
    }
}
