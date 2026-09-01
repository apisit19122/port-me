import Foundation

/// ความสัมพันธ์แม่-ลูกของ process ทั้งหมดในหนึ่ง snapshot
public struct ProcessTree: Sendable {
    private let byPID: [pid_t: ProcessRecord]
    private let childrenByPID: [pid_t: [pid_t]]

    public init(processes: [ProcessRecord]) {
        byPID = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        childrenByPID = Dictionary(grouping: processes, by: \.ppid).mapValues { $0.map(\.pid).sorted() }
    }

    public func record(_ pid: pid_t) -> ProcessRecord? { byPID[pid] }

    /// ลูกหลานทั้งหมดของ pid เรียงจากใกล้ไปไกล ไม่รวมตัวมันเอง
    public func descendants(of pid: pid_t) -> [pid_t] {
        var found: [pid_t] = []
        var seen: Set<pid_t> = [pid]
        var queue = childrenByPID[pid] ?? []
        while let next = queue.first {
            queue.removeFirst()
            guard seen.insert(next).inserted else { continue }
            found.append(next)
            queue.append(contentsOf: childrenByPID[next] ?? [])
        }
        return found
    }

    public func ancestors(of pid: pid_t) -> [pid_t] {
        var found: [pid_t] = []
        var seen: Set<pid_t> = [pid]
        var current = pid
        while let record = byPID[current], record.ppid > 0, seen.insert(record.ppid).inserted {
            found.append(record.ppid)
            current = record.ppid
        }
        return found
    }

    /// ไต่ขึ้นจาก listener จนชนกำแพง แล้วคืน process ที่อยู่ใต้กำแพงนั้น = root ของ dev tree
    public func devTreeRoot(of pid: pid_t, protectedPIDs: Set<pid_t> = []) -> pid_t {
        var current = pid
        var seen: Set<pid_t> = [pid]
        while let record = byPID[current] {
            let parentPID = record.ppid
            guard !protectedPIDs.contains(parentPID), seen.insert(parentPID).inserted else { return current }
            guard let parent = byPID[parentPID], !ProcessBarrier.stopsTreeWalk(parent) else { return current }
            current = parentPID
        }
        return current
    }
}
