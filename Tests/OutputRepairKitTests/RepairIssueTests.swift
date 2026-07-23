import XCTest
@testable import OutputRepairKit

final class RepairIssueTests: XCTestCase {
    func testDescriptionWithPathExpectedAndObserved() {
        let issue = RepairIssue(path: "tempC", problem: "wrong type", expected: "integer", observed: "\"hot\"")
        XCTAssertEqual(issue.description, "tempC: wrong type (expected integer, observed \"hot\")")
    }

    func testDescriptionWithoutPath() {
        let issue = RepairIssue(path: "", problem: "not a JSON object")
        XCTAssertEqual(issue.description, "not a JSON object")
    }

    func testDescriptionWithExpectedOnly() {
        let issue = RepairIssue(path: "city", problem: "missing", expected: "string")
        XCTAssertEqual(issue.description, "city: missing (expected string)")
    }

    func testDescriptionWithObservedOnly() {
        let issue = RepairIssue(path: "x", problem: "bad", observed: "5")
        XCTAssertEqual(issue.description, "x: bad (observed 5)")
    }

    func testEquatable() {
        let one = RepairIssue(path: "a", problem: "b")
        let two = RepairIssue(path: "a", problem: "b")
        XCTAssertEqual(one, two)
        XCTAssertNotEqual(one, RepairIssue(path: "a", problem: "c"))
    }
}
