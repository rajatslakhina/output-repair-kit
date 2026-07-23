import XCTest
@testable import OutputRepairKit

final class RepairErrorTests: XCTestCase {
    func testExhaustedDescriptionCountsFinalIssues() {
        let failure = RepairFailure.exhausted(
            attempts: 3,
            issueHistory: [[RepairIssue(path: "a", problem: "x")], [RepairIssue(path: "b", problem: "y")]],
            lastRaw: "raw"
        )
        XCTAssertEqual(
            failure.errorDescription,
            "Output still invalid after 3 attempt(s); 1 unresolved issue(s) on the final attempt."
        )
    }

    func testExhaustedDescriptionWithEmptyHistory() {
        let failure = RepairFailure.exhausted(attempts: 1, issueHistory: [], lastRaw: "raw")
        XCTAssertEqual(
            failure.errorDescription,
            "Output still invalid after 1 attempt(s); 0 unresolved issue(s) on the final attempt."
        )
    }

    func testProducerFailedDescription() {
        let failure = RepairFailure.producerFailed(attempt: 2, message: "boom")
        XCTAssertEqual(failure.errorDescription, "Producer failed on attempt 2: boom")
    }

    func testEquatable() {
        XCTAssertEqual(
            RepairFailure.producerFailed(attempt: 1, message: "a"),
            RepairFailure.producerFailed(attempt: 1, message: "a")
        )
        XCTAssertNotEqual(
            RepairFailure.producerFailed(attempt: 1, message: "a"),
            RepairFailure.producerFailed(attempt: 2, message: "a")
        )
    }
}
