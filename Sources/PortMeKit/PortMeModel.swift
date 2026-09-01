import Foundation
import Observation

@MainActor
@Observable
public final class PortMeModel {
    /// แถวที่ควรแสดงจริงตามการตั้งค่าปัจจุบัน
    public private(set) var visibleServers: [DevServer] = []
    /// จำนวนแถวแอป GUI ที่ถูกซ่อนอยู่ ใช้บอก user ว่ายังมีอะไรที่ไม่ได้แสดง
    public private(set) var hiddenAppCount = 0
    public private(set) var isKilling = false
    public private(set) var status: String?

    public private(set) var showAll: Bool

    /// เปลี่ยนผ่านเมธอด ไม่ใช่ `didSet` บน property ที่ผูกกับ Toggle โดยตรง
    /// เพราะการเขียนค่าลง UserDefaults ต้องเกิดจากการที่ user กดจริง ไม่ใช่ผลข้างเคียงของการวาด view
    public func setShowAll(_ newValue: Bool) {
        guard newValue != showAll else { return }
        showAll = newValue
        settings.showAll = newValue
        applyFilter()
    }

    private var allServers: [DevServer] = []
    private var snapshot: ProcessSnapshot = .empty
    private let scanner: ProcessScanning
    private let killer: ProcessKiller
    private let settings: SettingsStore

    public init(
        scanner: ProcessScanning = LibprocScanner(),
        killer: ProcessKiller = ProcessKiller(),
        settings: SettingsStore = SettingsStore()
    ) {
        self.scanner = scanner
        self.killer = killer
        self.settings = settings
        showAll = settings.showAll
    }

    public func refresh() {
        snapshot = scanner.scan()
        allServers = DevServerBuilder.build(
            from: snapshot,
            protectedPIDs: ProtectedProcesses.current(in: snapshot)
        )
        applyFilter()
    }

    public func kill(_ server: DevServer) async {
        await runKill(of: [server])
    }

    public func killAll() async {
        await runKill(of: visibleServers)
    }

    private func runKill(of servers: [DevServer]) async {
        guard !servers.isEmpty, !isKilling else { return }
        isKilling = true
        status = nil
        defer { isKilling = false }

        let protectedPIDs = ProtectedProcesses.current(in: snapshot)
        var reports: [KillReport] = []
        for server in servers {
            reports.append(await killer.kill(server, in: snapshot, protectedPIDs: protectedPIDs))
        }

        refresh()
        status = summary(of: reports, servers: servers)
    }

    private func summary(of reports: [KillReport], servers: [DevServer]) -> String? {
        let failed = reports.filter { !$0.succeeded }
        guard failed.isEmpty else {
            let names = servers.filter { server in failed.contains { $0.rootPID == server.rootPID } }.map(\.name)
            return "ฆ่าไม่สำเร็จ: \(names.joined(separator: ", "))"
        }
        // บอกเฉพาะตอนต้องใช้ SIGKILL — เป็นสัญญาณว่า process นั้นไม่ยอมปิดตัวเองสวย ๆ
        guard reports.contains(where: \.escalated) else { return nil }
        return "ต้องใช้ SIGKILL กับ \(reports.filter(\.escalated).count) รายการ"
    }

    private func applyFilter() {
        let apps = allServers.filter { $0.kind == .guiApp }
        visibleServers = showAll ? allServers : allServers.filter { $0.kind == .dev }
        hiddenAppCount = showAll ? 0 : apps.count
    }
}
