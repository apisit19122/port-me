import AppKit
import SwiftUI
import XCTest
@testable import PortMeKit

/// วาดรายการลงไฟล์ภาพเพื่อให้ตรวจหน้าตาได้โดยไม่ต้องคลิกไอคอนบน menu bar
///
/// ImageRenderer วาดของที่อยู่ใน ScrollView ไม่ออก จึงเรนเดอร์ `DevServerList` ตรง ๆ
@MainActor
final class PopoverRenderTests: XCTestCase {
    private let servers = [
        DevServer(
            rootPID: 101,
            listenerPIDs: [103],
            name: "next-server",
            ports: [3000],
            workingDirectory: "/Users/dev/oss-portal",
            kind: .dev
        ),
        DevServer(
            rootPID: 201,
            listenerPIDs: [203, 204],
            name: "bun, node",
            ports: [9000, 9001],
            workingDirectory: "/Users/dev/workspace-ui",
            kind: .dev
        ),
        DevServer(
            rootPID: 300,
            listenerPIDs: [300],
            name: "OrbStack Helper",
            ports: [3306, 6380],
            workingDirectory: nil,
            kind: .guiApp
        ),
    ]

    func testListRendersEveryRowWithItsPortsAndFolder() throws {
        let renderer = ImageRenderer(
            content: DevServerList(servers: servers, onKill: { _ in })
                .frame(width: 340)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        renderer.scale = 2

        let image = try XCTUnwrap(renderer.nsImage, "เรนเดอร์รายการไม่สำเร็จ")
        XCTAssertEqual(image.size.width, 340)
        // สามแถว แต่ละแถวสูงกว่า 30pt — ถ้าเรนเดอร์ได้แค่กรอบเปล่าความสูงจะไม่ถึง
        XCTAssertGreaterThan(image.size.height, 90)

        try write(image, named: "dev-server-list.png")
    }

    func testEmptyListTakesUpNoHeightWhichIsWhyThePopoverSwapsInAnEmptyState() throws {
        let renderer = ImageRenderer(
            content: DevServerList(servers: [], onKill: { _ in })
                .frame(width: 340)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        XCTAssertEqual(renderer.nsImage?.size.height ?? 0, 0)
    }

    /// เขียนลง `.build/preview/` ไว้ให้เปิดดูเองหลังรันเทสต์
    private func write(_ image: NSImage, named name: String) throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/preview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent(name))
    }
}
