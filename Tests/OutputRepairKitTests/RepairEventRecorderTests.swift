import XCTest
@testable import OutputRepairKit

final class RepairEventRecorderTests: XCTestCase {
    func testRecordsEventsInOrderWithTimestamps() async {
        let stamp = Date(timeIntervalSince1970: 500)
        let recorder = InMemoryRepairEventRecorder()
        await recorder.record(.produced(attempt: 1), at: stamp)
        await recorder.record(.invalid(attempt: 1, issues: [RepairIssue(path: "a", problem: "x")]), at: stamp)
        await recorder.record(.validated(attempt: 2), at: stamp)

        let count = await recorder.count
        XCTAssertEqual(count, 3)

        let events = await recorder.events()
        XCTAssertEqual(events, [
            .produced(attempt: 1),
            .invalid(attempt: 1, issues: [RepairIssue(path: "a", problem: "x")]),
            .validated(attempt: 2)
        ])

        let stamped = await recorder.timestampedEvents()
        XCTAssertEqual(stamped.count, 3)
        XCTAssertTrue(stamped.allSatisfy { $0.timestamp == stamp })
        XCTAssertEqual(stamped.first?.event, .produced(attempt: 1))
    }
}
