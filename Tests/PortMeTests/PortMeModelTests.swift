import XCTest
@testable import PortMeKit

/// ระบบจำลองที่ทั้งสแกนและรับสัญญาณ — ฆ่าแล้วการสแกนครั้งต่อไปต้องเห็นผลจริง
private final class FakeSystem: ProcessScanning, SignalSending, @unchecked Sendable {
    private let lock = NSLock()
    private var alive: Set<pid_t>
    private let base: ProcessSnapshot
    private let stubborn: Set<pid_t>

    init(base: ProcessSnapshot = Fixtures.snapshot, stubborn: Set<pid_t> = []) {
        self.base = base
        self.stubborn = stubborn
        alive = Set(base.processes.map(\.pid))
    }

    func scan() -> ProcessSnapshot {
        lock.withLock {
            ProcessSnapshot(
                processes: base.processes.filter { alive.contains($0.pid) },
                listeners: base.listeners.filter { alive.contains($0.pid) }
            )
        }
    }

    func send(_ signal: Int32, to pid: pid_t) {
        lock.withLock {
            if signal == SIGKILL || !stubborn.contains(pid) { alive.remove(pid) }
        }
    }

    func isAlive(_ pid: pid_t) -> Bool {
        lock.withLock { alive.contains(pid) }
    }
}

@MainActor
final class PortMeModelTests: XCTestCase {
    private func makeModel(system: FakeSystem = FakeSystem()) -> PortMeModel {
        let suite = UserDefaults(suiteName: "portme.tests.\(UUID().uuidString)")!
        return PortMeModel(
            scanner: system,
            killer: ProcessKiller(
                signaller: system,
                gracePeriod: .milliseconds(30),
                pollInterval: .milliseconds(10),
                sleep: { _ in }
            ),
            settings: SettingsStore(defaults: suite)
        )
    }

    func testRefreshShowsDevServersAndHidesGUIApps() {
        let model = makeModel()
        model.refresh()

        XCTAssertEqual(model.visibleServers.map(\.ports), [[3000], [9000, 9001]])
        XCTAssertEqual(model.hiddenAppCount, 1)
    }

    func testShowAllRevealsGUIAppsAndClearsTheHiddenCount() {
        let model = makeModel()
        model.refresh()
        model.setShowAll(true)

        XCTAssertTrue(model.visibleServers.contains { $0.ports == [51659] })
        XCTAssertEqual(model.hiddenAppCount, 0)
    }

    func testShowAllSurvivesANewModelBecauseItIsPersisted() {
        let suite = UserDefaults(suiteName: "portme.tests.\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: suite)
        PortMeModel(scanner: FakeSystem(), settings: settings).setShowAll(true)

        XCTAssertTrue(PortMeModel(scanner: FakeSystem(), settings: settings).showAll)
    }

    func testKillingARowRemovesItWithoutTouchingTheOthers() async {
        let model = makeModel()
        model.refresh()
        let target = model.visibleServers.first { $0.ports == [3000] }!

        await model.kill(target)

        XCTAssertEqual(model.visibleServers.map(\.ports), [[9000, 9001]])
    }

    func testKillingOneRowTakesDownEveryListenerInThatTree() async {
        let model = makeModel()
        model.refresh()
        let monorepo = model.visibleServers.first { $0.ports.contains(9000) }!

        await model.kill(monorepo)

        XCTAssertFalse(model.visibleServers.contains { $0.ports.contains(9001) })
    }

    func testKillAllEmptiesTheList() async {
        let model = makeModel()
        model.refresh()

        await model.killAll()

        XCTAssertTrue(model.visibleServers.isEmpty)
    }

    func testKillAllLeavesHiddenGUIAppsAlone() async {
        let system = FakeSystem()
        let model = makeModel(system: system)
        model.refresh()

        await model.killAll()
        model.setShowAll(true)

        // แถวแอปที่ถูกซ่อนไม่เคยอยู่ในรายการ จึงต้องไม่ถูกฆ่าไปด้วย
        XCTAssertTrue(model.visibleServers.contains { $0.ports == [51659] })
    }

    func testStatusStaysQuietWhenEverythingExitsOnSIGTERM() async {
        let model = makeModel()
        model.refresh()

        await model.killAll()

        XCTAssertNil(model.status)
    }

    func testStatusReportsWhenSIGKILLWasNeeded() async {
        let model = makeModel(system: FakeSystem(stubborn: [103]))
        model.refresh()
        let target = model.visibleServers.first { $0.ports == [3000] }!

        await model.kill(target)

        XCTAssertEqual(model.status, "ต้องใช้ SIGKILL กับ 1 รายการ")
    }

    func testRefreshOnAnEmptySystemProducesNoRows() {
        let model = makeModel(system: FakeSystem(base: .empty))
        model.refresh()

        XCTAssertTrue(model.visibleServers.isEmpty)
        XCTAssertEqual(model.hiddenAppCount, 0)
    }
}
