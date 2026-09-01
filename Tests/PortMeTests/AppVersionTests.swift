import XCTest
@testable import PortMeKit

final class AppVersionTests: XCTestCase {
    func testVersionFromTheBundleIsPrefixed() {
        XCTAssertEqual(AppVersion.display(shortVersion: "0.1.0"), "v0.1.0")
    }

    func testRunningWithoutABundleReportsDevRatherThanAWrongNumber() {
        XCTAssertEqual(AppVersion.display(shortVersion: nil), "dev")
        XCTAssertEqual(AppVersion.display(shortVersion: ""), "dev")
    }

    func testShippedBundleCarriesTheVersionTheAppWillShow() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/Info.plist")
        let contents = try Data(contentsOf: plist)
        let parsed = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: contents, format: nil) as? [String: Any]
        )

        // เลขเวอร์ชันอยู่ใน Info.plist ที่เดียว เทสต์นี้กันไม่ให้ key หายไปเงียบ ๆ ตอนแก้ไฟล์
        let short = try XCTUnwrap(parsed["CFBundleShortVersionString"] as? String)
        XCTAssertFalse(short.isEmpty)
        XCTAssertNotNil(parsed["CFBundleVersion"] as? String)
    }
}
