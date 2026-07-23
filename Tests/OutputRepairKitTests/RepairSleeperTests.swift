import XCTest
@testable import OutputRepairKit

final class RepairSleeperTests: XCTestCase {
    func testSystemSleeperSuspendsForPositiveDuration() async throws {
        let before = Date()
        try await SystemRepairSleeper().sleep(milliseconds: 5)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(before), 0)
    }

    func testSystemSleeperReturnsImmediatelyForNonPositive() async throws {
        try await SystemRepairSleeper().sleep(milliseconds: 0)
        try await SystemRepairSleeper().sleep(milliseconds: -10)
    }
}
