import Foundation

/// โหมดบรรทัดคำสั่งไว้ตรวจว่า scanner กับ filter เห็นอะไรบ้าง โดยไม่ต้องเปิด UI
public enum PortMeCLI {
    public static func printList(showAll: Bool) {
        let scanner = LibprocScanner()
        let snapshot = scanner.scan()
        let servers = DevServerBuilder.build(from: snapshot, protectedPIDs: ProtectedProcesses.current(in: snapshot))
        let shown = servers.filter { showAll || $0.kind == .dev }

        guard !shown.isEmpty else {
            print(showAll ? "ไม่มี process ไหนถือ port อยู่" : "ไม่มี dev server ถือ port อยู่ (ลอง --all เพื่อดูแอป GUI ด้วย)")
            return
        }

        for server in shown {
            let ports = server.ports.map { ":\($0)" }.joined(separator: " ")
            let folder = server.projectFolder.map { " · \($0)" } ?? ""
            let tag = server.kind == .guiApp ? " [app]" : ""
            print("\(server.name)\(folder)\(tag)  \(ports)  root=\(server.rootPID) listeners=\(server.listenerPIDs)")
        }
    }
}
