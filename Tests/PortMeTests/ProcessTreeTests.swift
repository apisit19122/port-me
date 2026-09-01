import XCTest
@testable import PortMeKit

final class ProcessTreeTests: XCTestCase {
    private let tree = ProcessTree(processes: Fixtures.snapshot.processes)

    func testDescendantsCoverEveryGeneration() {
        XCTAssertEqual(Set(tree.descendants(of: 201)), [202, 203, 204])
        XCTAssertEqual(tree.descendants(of: 103), [])
    }

    func testAncestorsRunFromParentToTheTop() {
        XCTAssertEqual(tree.ancestors(of: 103), [102, 101, 100, 1])
    }

    func testTreeWalkStopsAtTheShellSoTheTerminalSurvives() {
        XCTAssertEqual(tree.devTreeRoot(of: 103), 101)
        XCTAssertEqual(tree.devTreeRoot(of: 204), 201)
    }

    func testAProcessDirectlyUnderLaunchdIsItsOwnRoot() {
        XCTAssertEqual(tree.devTreeRoot(of: 300), 300)
    }

    func testCyclicParentLinksDoNotHang() {
        let cyclic = ProcessTree(processes: [
            .init(pid: 10, ppid: 11, executablePath: Fixtures.nodePath),
            .init(pid: 11, ppid: 10, executablePath: Fixtures.nodePath),
        ])
        XCTAssertNotNil(cyclic.devTreeRoot(of: 10))
        XCTAssertEqual(Set(cyclic.descendants(of: 10)), [11])
    }

    func testUnknownPIDIsItsOwnRoot() {
        XCTAssertEqual(tree.devTreeRoot(of: 9999), 9999)
    }
}
