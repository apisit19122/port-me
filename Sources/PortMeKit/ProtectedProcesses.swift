import Foundation

public enum ProtectedProcesses {
    /// ตัว Port me เองและบรรพบุรุษทั้งสาย — ถ้า dev server ถูกเปิดจาก terminal ที่เป็นแม่ของเรา
    /// การไต่ tree ต้องไม่ไปจบที่ process ที่ฆ่าแล้วเราตายตาม
    public static func current(in snapshot: ProcessSnapshot, pid: pid_t = getpid()) -> Set<pid_t> {
        let tree = ProcessTree(processes: snapshot.processes)
        return Set([pid] + tree.ancestors(of: pid))
    }
}
