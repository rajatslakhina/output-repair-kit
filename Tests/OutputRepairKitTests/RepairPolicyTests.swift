import XCTest
@testable import OutputRepairKit

final class RepairPolicyTests: XCTestCase {
    func testDefaults() {
        let policy = RepairPolicy()
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.backoff, .none)
    }

    func testClampsMaxAttemptsToAtLeastOne() {
        XCTAssertEqual(RepairPolicy(maxAttempts: 0).maxAttempts, 1)
        XCTAssertEqual(RepairPolicy(maxAttempts: -4).maxAttempts, 1)
        XCTAssertEqual(RepairPolicy(maxAttempts: 6).maxAttempts, 6)
    }
}
