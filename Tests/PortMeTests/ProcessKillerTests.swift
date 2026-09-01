import XCTest
@testable import PortMeKit

/// signaller ปลอมที่บันทึกสัญญาณและกำหนดได้ว่า pid ไหนดื้อไม่ยอมตายกับ SIGTERM
private final class FakeSignaller: SignalSending, @unchecked Sendable {
    private let lock = NSLock()
    private var _alive: Set<pid_t>
    private var _sent: [(signal: Int32, pid: pid_t)] = []
    private let ignoresSIGTERM: Set<pid_t>

    init(alive: Set<pid_t>, ignoresSIGTERM: Set<pid_t> = []) {
        _alive = alive
        self.ignoresSIGTERM = ignoresSIGTERM
    }

    var sent: [(signal: Int32, pid: pid_t)] {
        lock.withLock { _sent }
    }

    func send(_ signal: Int32, to pid: pid_t) {
        lock.withLock {
            _sent.append((signal, pid))
            guard _alive.contains(pid) else { return }
            if signal == SIGKILL || !ignoresSIGTERM.contains(pid) { _alive.remove(pid) }
        }
    }

    func isAlive(_ pid: pid_t) -> Bool {
        lock.withLock { _alive.contains(pid) }
    }
}

final class ProcessKillerTests: XCTestCase {
    private func killer(_ signaller: SignalSending) -> ProcessKiller {
        // เร่งเวลาให้เทสต์ไม่ต้องรอจริง 3 วินาที
        ProcessKiller(
            signaller: signaller,
            gracePeriod: .milliseconds(30),
            pollInterval: .milliseconds(10),
            sleep: { _ in }
        )
    }

    private func monorepoServer() -> DevServer {
        DevServerBuilder.build(from: Fixtures.snapshot).first { $0.ports.contains(9000) }!
    }

    func testWholeTreeIsSignalledNotJustTheListener() async {
        let signaller = FakeSignaller(alive: [201, 202, 203, 204])
        let report = await killer(signaller).kill(monorepoServer(), in: Fixtures.snapshot)

        XCTAssertEqual(Set(report.targetedPIDs), [201, 202, 203, 204])
        XCTAssertTrue(report.succeeded)
    }

    func testRootIsSignalledBeforeItsChildrenSoASupervisorCannotRespawn() async {
        let signaller = FakeSignaller(alive: [201, 202, 203, 204])
        _ = await killer(signaller).kill(monorepoServer(), in: Fixtures.snapshot)

        XCTAssertEqual(signaller.sent.first?.pid, 201)
    }

    func testProcessThatExitsOnSIGTERMIsNotSIGKILLed() async {
        let signaller = FakeSignaller(alive: [201, 202, 203, 204])
        let report = await killer(signaller).kill(monorepoServer(), in: Fixtures.snapshot)

        XCTAssertFalse(report.escalated)
        XCTAssertFalse(signaller.sent.contains { $0.signal == SIGKILL })
    }

    func testProcessThatIgnoresSIGTERMIsSIGKILLedAfterTheGracePeriod() async {
        let signaller = FakeSignaller(alive: [201, 202, 203, 204], ignoresSIGTERM: [203])
        let report = await killer(signaller).kill(monorepoServer(), in: Fixtures.snapshot)

        XCTAssertTrue(report.escalated)
        XCTAssertTrue(report.succeeded)
        XCTAssertEqual(signaller.sent.filter { $0.signal == SIGKILL }.map(\.pid), [203])
    }

    func testOnlyTheStubbornProcessGetsSIGKILLedNotTheWholeTreeAgain() async {
        let signaller = FakeSignaller(alive: [201, 202, 203, 204], ignoresSIGTERM: [203])
        _ = await killer(signaller).kill(monorepoServer(), in: Fixtures.snapshot)

        XCTAssertEqual(signaller.sent.filter { $0.signal == SIGKILL }.count, 1)
    }

    func testSystemProcessesInsideATreeAreNeverSignalled() async {
        let snapshot = ProcessSnapshot(
            processes: Fixtures.snapshot.processes + [
                .init(pid: 205, ppid: 202, executablePath: Fixtures.rapportdPath),
            ],
            listeners: Fixtures.snapshot.listeners
        )
        let server = DevServerBuilder.build(from: snapshot).first { $0.ports.contains(9000) }!
        let signaller = FakeSignaller(alive: [201, 202, 203, 204, 205])
        let report = await killer(signaller).kill(server, in: snapshot)

        XCTAssertFalse(report.targetedPIDs.contains(205))
        XCTAssertFalse(signaller.sent.contains { $0.pid == 205 })
    }

    func testOurOwnProcessIsNeverSignalledEvenIfItLandsInsideTheTree() async {
        let signaller = FakeSignaller(alive: [201, 202, 203, 204])
        let report = await killer(signaller).kill(monorepoServer(), in: Fixtures.snapshot, protectedPIDs: [202])

        XCTAssertFalse(report.targetedPIDs.contains(202))
    }

    func testKillingAlreadyDeadTreeReportsSuccessWithoutEscalating() async {
        let signaller = FakeSignaller(alive: [])
        let report = await killer(signaller).kill(monorepoServer(), in: Fixtures.snapshot)

        XCTAssertTrue(report.succeeded)
        XCTAssertFalse(report.escalated)
    }
}
