import Darwin
import Foundation

public struct KillReport: Sendable, Equatable {
    public let rootPID: pid_t
    public let targetedPIDs: [pid_t]
    public let survivingPIDs: [pid_t]
    /// จริงเมื่อหมดเวลารอแล้วยังมีตัวรอด จนต้องส่ง SIGKILL
    public let escalated: Bool

    public var succeeded: Bool { survivingPIDs.isEmpty }
}

public protocol SignalSending: Sendable {
    func send(_ signal: Int32, to pid: pid_t)
    func isAlive(_ pid: pid_t) -> Bool
}

public struct POSIXSignaller: SignalSending {
    private let scanner = LibprocScanner()

    public init() {}

    public func send(_ signal: Int32, to pid: pid_t) {
        _ = Darwin.kill(pid, signal)
    }

    public func isAlive(_ pid: pid_t) -> Bool { scanner.isAlive(pid) }
}

public struct ProcessKiller: Sendable {
    private let signaller: SignalSending
    private let gracePeriod: Duration
    private let pollInterval: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    public init(
        signaller: SignalSending = POSIXSignaller(),
        gracePeriod: Duration = .seconds(3),
        pollInterval: Duration = .milliseconds(100),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.signaller = signaller
        self.gracePeriod = gracePeriod
        self.pollInterval = pollInterval
        self.sleep = sleep
    }

    public func kill(_ server: DevServer, in snapshot: ProcessSnapshot, protectedPIDs: Set<pid_t> = []) async -> KillReport {
        let tree = ProcessTree(processes: snapshot.processes)
        let targets = targetPIDs(root: server.rootPID, tree: tree, protectedPIDs: protectedPIDs)

        guard !targets.isEmpty else {
            return KillReport(rootPID: server.rootPID, targetedPIDs: [], survivingPIDs: [], escalated: false)
        }

        for pid in targets { signaller.send(SIGTERM, to: pid) }
        var alive = await waitForExit(of: targets, within: gracePeriod)

        let escalated = !alive.isEmpty
        if escalated {
            for pid in alive { signaller.send(SIGKILL, to: pid) }
            // SIGKILL ไม่มีทางถูกปฏิเสธ รอแค่ให้ kernel เก็บกวาดเสร็จ
            alive = await waitForExit(of: alive, within: .milliseconds(500))
        }

        return KillReport(rootPID: server.rootPID, targetedPIDs: targets, survivingPIDs: alive, escalated: escalated)
    }

    /// root มาก่อนลูกหลานเสมอ: ถ้าฆ่าลูกก่อน ตัว supervisor อย่าง `pnpm` หรือ `nodemon`
    /// ที่ยังอยู่จะ respawn process ใหม่ขึ้นมาถือ port ต่อทันที
    func targetPIDs(root: pid_t, tree: ProcessTree, protectedPIDs: Set<pid_t>) -> [pid_t] {
        ([root] + tree.descendants(of: root)).filter { pid in
            guard let record = tree.record(pid) else { return false }
            return !ProcessBarrier.isProtected(record, protectedPIDs: protectedPIDs)
        }
    }

    private func waitForExit(of pids: [pid_t], within limit: Duration) async -> [pid_t] {
        var remaining = pids
        var waited = Duration.zero
        while !remaining.isEmpty, waited < limit {
            try? await sleep(pollInterval)
            waited += pollInterval
            remaining = remaining.filter(signaller.isAlive)
        }
        return remaining
    }
}
