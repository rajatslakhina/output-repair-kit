import XCTest
@testable import OutputRepairKit

final class RepairPromptingTests: XCTestCase {
    func testDefaultRepairPrompterEnumeratesEveryIssue() {
        let context = RepairContext(
            originalPrompt: "Report the weather.",
            lastRaw: "{}",
            issues: [
                RepairIssue(path: "a", problem: "missing"),
                RepairIssue(path: "b", problem: "bad", expected: "int")
            ],
            attempt: 1
        )
        let text = DefaultRepairPrompter().repairPrompt(context)
        XCTAssertTrue(text.contains("Report the weather."))
        XCTAssertTrue(text.contains("Your previous reply was rejected"))
        XCTAssertTrue(text.contains("{}"))
        XCTAssertTrue(text.contains("Fix exactly these 2 problem(s):"))
        XCTAssertTrue(text.contains("1. a: missing"))
        XCTAssertTrue(text.contains("2. b: bad (expected int)"))
        XCTAssertTrue(text.contains("Return only the corrected output"))
    }

    func testRepairContextEquatable() {
        let one = RepairContext(originalPrompt: "p", lastRaw: "r", issues: [], attempt: 2)
        let two = RepairContext(originalPrompt: "p", lastRaw: "r", issues: [], attempt: 2)
        XCTAssertEqual(one, two)
    }
}
