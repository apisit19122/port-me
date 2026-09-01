import Darwin
import Foundation

public protocol ProcessScanning: Sendable {
    func scan() -> ProcessSnapshot
    func isAlive(_ pid: pid_t) -> Bool
}

/// อ่าน process และ socket ตรงจาก libproc ของ kernel — เร็วกว่าและแน่นอนกว่าการ shell out ไป `lsof`
///
/// สแกนเฉพาะ process ของ user ปัจจุบัน ไม่ใช่แค่เพราะเป็นเกณฑ์ในโดเมน แต่เพราะ `proc_pidfdinfo`
/// ของ process ที่ uid อื่นต้องใช้สิทธิ์ root อยู่แล้ว
public struct LibprocScanner: ProcessScanning {
    /// `PROC_PIDPATHINFO_MAXSIZE` จาก `sys/proc_info.h` ไม่ถูก export เข้ามาใน Swift
    private static let pathBufferSize = 4 * Int(MAXPATHLEN)
    /// `SZOMB` จาก `sys/proc.h` — zombie ยังตอบ `kill(pid, 0)` ว่ามีอยู่ แต่ปล่อย port ไปแล้ว
    private static let zombieStatus: UInt32 = 5

    private let uid: uid_t

    public init(uid: uid_t = getuid()) {
        self.uid = uid
    }

    public func scan() -> ProcessSnapshot {
        var processes: [ProcessRecord] = []
        var listeners: [ListeningSocket] = []

        for pid in Self.allPIDs() {
            guard let info = shortInfo(pid), info.pbsi_uid == uid, info.pbsi_status != Self.zombieStatus else { continue }
            guard let path = executablePath(pid) else { continue }

            processes.append(
                ProcessRecord(
                    pid: pid,
                    ppid: pid_t(bitPattern: info.pbsi_ppid),
                    executablePath: path,
                    workingDirectory: workingDirectory(pid)
                )
            )
            listeners.append(contentsOf: listeningPorts(pid).map { ListeningSocket(pid: pid, port: $0) })
        }

        return ProcessSnapshot(processes: processes, listeners: listeners)
    }

    /// zombie นับว่าตายแล้ว — process ที่รอ parent มาเก็บศพไม่ได้ถือ port ไว้อีกต่อไป
    public func isAlive(_ pid: pid_t) -> Bool {
        guard let info = shortInfo(pid) else { return false }
        return info.pbsi_status != Self.zombieStatus
    }

    // MARK: - libproc

    static func allPIDs() -> [pid_t] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return [] }
        var buffer = [pid_t](repeating: 0, count: Int(byteCount) / MemoryLayout<pid_t>.size)
        let written = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &buffer, byteCount)
        guard written > 0 else { return [] }
        return buffer.prefix(Int(written) / MemoryLayout<pid_t>.size).filter { $0 > 0 }
    }

    private func shortInfo(_ pid: pid_t) -> proc_bsdshortinfo? {
        var info = proc_bsdshortinfo()
        let size = Int32(MemoryLayout<proc_bsdshortinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    private func executablePath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Self.pathBufferSize)
        guard proc_pidpath(pid, &buffer, UInt32(Self.pathBufferSize)) > 0 else { return nil }
        let path = String(cString: buffer)
        return path.isEmpty ? nil : path
    }

    private func workingDirectory(_ pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafePointer(to: info.pvi_cdir.vip_path) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        return path.isEmpty ? nil : path
    }

    /// port ที่ pid นี้ LISTEN อยู่ — dedupe แล้วเพราะ socket IPv4 กับ IPv6 บน port เดียวกันคือ listener เดียว
    private func listeningPorts(_ pid: pid_t) -> Set<UInt16> {
        let byteCount = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard byteCount > 0 else { return [] }
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(byteCount) / MemoryLayout<proc_fdinfo>.size)
        let written = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &descriptors, byteCount)
        guard written > 0 else { return [] }

        var ports: Set<UInt16> = []
        for descriptor in descriptors.prefix(Int(written) / MemoryLayout<proc_fdinfo>.size) {
            guard descriptor.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) else { continue }
            var socketInfo = socket_fdinfo()
            let size = Int32(MemoryLayout<socket_fdinfo>.size)
            guard proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDSOCKETINFO, &socketInfo, size) == size else { continue }
            guard socketInfo.psi.soi_kind == SOCKINFO_TCP else { continue }
            let tcp = socketInfo.psi.soi_proto.pri_tcp
            guard tcp.tcpsi_state == TSI_S_LISTEN else { continue }
            // insi_lport เก็บเป็น network byte order
            ports.insert(UInt16(bigEndian: UInt16(truncatingIfNeeded: tcp.tcpsi_ini.insi_lport)))
        }
        return ports
    }
}
