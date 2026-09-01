import Darwin
import Foundation

/// TCP listener จริงบน port ที่ kernel เลือกให้ ใช้ยืนยันว่า scanner มองเห็น socket ที่เพิ่งเปิด
final class TestListener {
    let port: UInt16
    private var descriptor: Int32

    init() throws {
        // ใช้ตัวแปรท้องถิ่นตลอด init เพราะ closure แตะ self ไม่ได้จนกว่า stored property จะครบ
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure.socketFailed(errno) }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = INADDR_ANY
        // port 0 = ให้ kernel เลือก port ว่างเอง จะได้ไม่ชนกับของจริงบนเครื่อง
        address.sin_port = 0

        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 1) == 0 else {
            let failure = errno
            Darwin.close(fd)
            throw Failure.bindFailed(failure)
        }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        guard named == 0 else {
            let failure = errno
            Darwin.close(fd)
            throw Failure.bindFailed(failure)
        }

        descriptor = fd
        port = UInt16(bigEndian: assigned.sin_port)
    }

    func close() {
        guard descriptor >= 0 else { return }
        Darwin.close(descriptor)
        descriptor = -1
    }

    deinit { close() }

    enum Failure: Error {
        case socketFailed(Int32)
        case bindFailed(Int32)
    }
}
