import XCTest
@testable import OutputRepairKit

final class RepairBackoffTests: XCTestCase {
    func testExponentialGrowth() {
        let backoff = RepairBackoff(baseMilliseconds: 100, multiplier: 2, capMilliseconds: 1000)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 1), 100)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 2), 200)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 3), 400)
    }

    func testCapsAndStabilizes() {
        let backoff = RepairBackoff(baseMilliseconds: 100, multiplier: 10, capMilliseconds: 150)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 1), 100)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 2), 150)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 3), 150)
    }

    func testBaseAboveCapClampsImmediately() {
        let backoff = RepairBackoff(baseMilliseconds: 500, multiplier: 2, capMilliseconds: 150)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 1), 150)
    }

    func testNoCapMeansUnbounded() {
        let backoff = RepairBackoff(baseMilliseconds: 100, multiplier: 2, capMilliseconds: 0)
        XCTAssertEqual(backoff.delayMilliseconds(forRetry: 3), 400)
    }

    func testGuardsReturnZero() {
        XCTAssertEqual(RepairBackoff.none.delayMilliseconds(forRetry: 3), 0)
        XCTAssertEqual(RepairBackoff(baseMilliseconds: 100).delayMilliseconds(forRetry: 0), 0)
    }

    func testClampsConstructorInputs() {
        let backoff = RepairBackoff(baseMilliseconds: -5, multiplier: 0, capMilliseconds: -1)
        XCTAssertEqual(backoff.baseMilliseconds, 0)
        XCTAssertEqual(backoff.multiplier, 1)
        XCTAssertEqual(backoff.capMilliseconds, 0)
    }
}
