import XCTest
@testable import OutputRepairKit

final class RepairRunTests: XCTestCase {
    func testRepairsIsAttemptsMinusOne() {
        let three = RepairRun(output: "x", attempts: 3, issueHistory: [], finalRaw: "x")
        XCTAssertEqual(three.repairs, 2)
        let one = RepairRun(output: "x", attempts: 1, issueHistory: [], finalRaw: "x")
        XCTAssertEqual(one.repairs, 0)
    }

    func testStatsDefaultsToZero() {
        XCTAssertEqual(
            RepairStats(),
            RepairStats(totalRuns: 0, succeeded: 0, exhausted: 0, producerFailures: 0, totalRepairs: 0)
        )
    }

    func testStatsFieldsAreMutable() {
        var stats = RepairStats()
        stats.totalRuns += 1
        stats.succeeded += 1
        XCTAssertEqual(stats.totalRuns, 1)
        XCTAssertEqual(stats.succeeded, 1)
    }
}
