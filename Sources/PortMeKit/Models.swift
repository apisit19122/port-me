import Foundation

/// หนึ่ง process ของ user ปัจจุบัน ตามที่เห็นในการสแกนหนึ่งครั้ง
public struct ProcessRecord: Sendable, Equatable, Identifiable {
    public let pid: pid_t
    public let ppid: pid_t
    public let executablePath: String
    public let workingDirectory: String?

    public init(pid: pid_t, ppid: pid_t, executablePath: String, workingDirectory: String? = nil) {
        self.pid = pid
        self.ppid = ppid
        self.executablePath = executablePath
        self.workingDirectory = workingDirectory
    }

    public var id: pid_t { pid }

    public var name: String {
        let last = (executablePath as NSString).lastPathComponent
        return last.isEmpty ? "pid \(pid)" : last
    }

    public var kind: ProcessKind { ProcessClassifier.kind(ofExecutableAt: executablePath) }
}

/// TCP socket ที่อยู่ในสถานะ LISTEN หนึ่งอัน
public struct ListeningSocket: Sendable, Equatable {
    public let pid: pid_t
    public let port: UInt16

    public init(pid: pid_t, port: UInt16) {
        self.pid = pid
        self.port = port
    }
}

/// ผลการสแกนหนึ่งครั้ง
public struct ProcessSnapshot: Sendable, Equatable {
    public let processes: [ProcessRecord]
    public let listeners: [ListeningSocket]

    public init(processes: [ProcessRecord], listeners: [ListeningSocket]) {
        self.processes = processes
        self.listeners = listeners
    }

    public static let empty = ProcessSnapshot(processes: [], listeners: [])
}

/// dev tree หนึ่งต้นที่มี listener อย่างน้อยหนึ่งตัว — หนึ่งแถวใน UI
public struct DevServer: Sendable, Equatable, Identifiable {
    public let rootPID: pid_t
    public let listenerPIDs: [pid_t]
    public let name: String
    public let ports: [UInt16]
    public let workingDirectory: String?
    public let kind: ProcessKind

    public init(
        rootPID: pid_t,
        listenerPIDs: [pid_t],
        name: String,
        ports: [UInt16],
        workingDirectory: String?,
        kind: ProcessKind
    ) {
        self.rootPID = rootPID
        self.listenerPIDs = listenerPIDs
        self.name = name
        self.ports = ports
        self.workingDirectory = workingDirectory
        self.kind = kind
    }

    public var id: pid_t { rootPID }

    /// ชื่อโฟลเดอร์โปรเจกต์ที่เอาไว้แยกว่า port นี้ของ repo ไหน
    public var projectFolder: String? {
        guard let workingDirectory, workingDirectory != "/" else { return nil }
        let last = (workingDirectory as NSString).lastPathComponent
        return last.isEmpty ? nil : last
    }
}
