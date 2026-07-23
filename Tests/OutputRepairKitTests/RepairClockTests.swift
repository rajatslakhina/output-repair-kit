import XCTest
@testable import OutputRepairKit

final class RepairClockTests: XCTestCase {
    func testSystemClockReturnsCurrentTime() {
        let before = Date()
        let now = SystemRepairClock().now
        let after = Date()
        XCTAssertGreaterThanOrEqual(now.timeIntervalSince1970, before.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(now.timeIntervalSince1970, after.timeIntervalSince1970)
    }

    func testFixedClockReturnsFixedInstant() {
        let fixed = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(FixedRepairClock(fixed: fixed).now, fixed)
    }
}
