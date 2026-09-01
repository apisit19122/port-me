import Foundation

public enum DevServerBuilder {
    /// รวม listener ที่อยู่ใน dev tree ต้นเดียวกันให้เหลือแถวเดียว
    ///
    /// การจับกลุ่มไม่ใช่แค่ความสวยงาม: `pnpm dev` ตัวเดียวใน monorepo สร้าง listener สองตัว
    /// ที่มี root ร่วมกัน ถ้าแยกเป็นสองแถว การกด Kill แถวหนึ่งจะทำให้อีกแถวหายไปเองโดยไม่มีเหตุผล
    public static func build(from snapshot: ProcessSnapshot, protectedPIDs: Set<pid_t> = []) -> [DevServer] {
        let tree = ProcessTree(processes: snapshot.processes)
        var portsByListener: [pid_t: Set<UInt16>] = [:]
        for socket in snapshot.listeners {
            portsByListener[socket.pid, default: []].insert(socket.port)
        }

        var listenersByRoot: [pid_t: [ProcessRecord]] = [:]
        for pid in portsByListener.keys.sorted() {
            guard let record = tree.record(pid), record.kind != .system else { continue }
            let root = tree.devTreeRoot(of: pid, protectedPIDs: protectedPIDs)
            listenersByRoot[root, default: []].append(record)
        }

        return listenersByRoot
            .map { root, listeners in
                makeServer(root: root, listeners: listeners, tree: tree, portsByListener: portsByListener)
            }
            .sorted { ($0.ports.first ?? .max, $0.rootPID) < ($1.ports.first ?? .max, $1.rootPID) }
    }

    private static func makeServer(
        root: pid_t,
        listeners: [ProcessRecord],
        tree: ProcessTree,
        portsByListener: [pid_t: Set<UInt16>]
    ) -> DevServer {
        let ports = listeners.reduce(into: Set<UInt16>()) { $0.formUnion(portsByListener[$1.pid] ?? []) }
        var names: [String] = []
        for listener in listeners where !names.contains(listener.name) { names.append(listener.name) }
        // แถวที่มี listener เป็น dev แม้ตัวเดียวก็ยังเป็นงานของ user ไม่ใช่ noise ของแอป GUI
        let kind: ProcessKind = listeners.contains { $0.kind == .dev } ? .dev : .guiApp

        return DevServer(
            rootPID: root,
            listenerPIDs: listeners.map(\.pid),
            name: names.joined(separator: ", "),
            ports: ports.sorted(),
            workingDirectory: kind == .dev ? projectDirectory(root: root, listeners: listeners, tree: tree) : nil,
            kind: kind
        )
    }

    /// cwd ของ root บอกโปรเจกต์ได้ตรงที่สุด — `pnpm dev` รันที่รากของ repo ส่วน listener ลูก
    /// อาจ chdir ลงไปใน workspace ย่อย ถ้า root ไม่มี cwd ที่ใช้ได้ค่อยถอยไปใช้ของ listener
    ///
    /// ใช้กับแถว dev เท่านั้น: cwd ของแอป GUI คือ container ของมัน ไม่เคยเป็นโปรเจกต์
    private static func projectDirectory(
        root: pid_t,
        listeners: [ProcessRecord],
        tree: ProcessTree
    ) -> String? {
        let candidates = [tree.record(root)?.workingDirectory] + listeners.map(\.workingDirectory)
        return candidates.compactMap { $0 }.first { $0 != "/" && !$0.isEmpty }
    }
}
