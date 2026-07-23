import XCTest
@testable import OutputRepairKit

final class OutputRepairLoopTests: XCTestCase {
    func testSucceedsOnFirstAttempt() async throws {
        let recorder = InMemoryRepairEventRecorder()
        let loop = OutputRepairLoop(
            contract: validWhenEqual("ok"),
            sleeper: ImmediateSleeper(),
            recorder: recorder
        )
        let run = try await loop.run(initialPrompt: "prompt", producer: ConstantProducer(reply: "ok"))

        XCTAssertEqual(run.attempts, 1)
        XCTAssertEqual(run.repairs, 0)
        XCTAssertEqual(run.output, "ok")
        XCTAssertTrue(run.issueHistory.isEmpty)
        XCTAssertEqual(run.finalRaw, "ok")

        let stats = await loop.stats
        XCTAssertEqual(stats.totalRuns, 1)
        XCTAssertEqual(stats.succeeded, 1)
        XCTAssertEqual(stats.totalRepairs, 0)

        let events = await recorder.events()
        XCTAssertEqual(events, [.produced(attempt: 1), .validated(attempt: 1)])
    }

    func testConvergesAfterRepairs() async throws {
        let recorder = InMemoryRepairEventRecorder()
        let loop = OutputRepairLoop(
            contract: validWhenEqual("good"),
            policy: RepairPolicy(maxAttempts: 4),
            sleeper: ImmediateSleeper(),
            recorder: recorder
        )
        let producer = ScriptProducer(["bad", "bad", "good"])
        let run = try await loop.run(initialPrompt: "start", producer: producer)

        XCTAssertEqual(run.attempts, 3)
        XCTAssertEqual(run.repairs, 2)
        XCTAssertEqual(run.issueHistory.count, 2)
        XCTAssertEqual(run.output, "good")

        let stats = await loop.stats
        XCTAssertEqual(stats.succeeded, 1)
        XCTAssertEqual(stats.totalRepairs, 2)

        let prompts = await producer.receivedPrompts()
        XCTAssertEqual(prompts.count, 3)
        XCTAssertEqual(prompts[0], "start")
        XCTAssertNotEqual(prompts[1], "start")

        let events = await recorder.events()
        XCTAssertEqual(events.filter { $0 == .repairScheduled(attempt: 1, delayMilliseconds: 0) }.count, 1)
        XCTAssertEqual(events.filter { $0 == .repairScheduled(attempt: 2, delayMilliseconds: 0) }.count, 1)
    }

    func testExhaustsAttemptBudget() async throws {
        let recorder = InMemoryRepairEventRecorder()
        let loop = OutputRepairLoop(
            contract: validWhenEqual("never"),
            policy: RepairPolicy(maxAttempts: 2),
            sleeper: ImmediateSleeper(),
            recorder: recorder
        )
        do {
            _ = try await loop.run(initialPrompt: "prompt", producer: ConstantProducer(reply: "bad"))
            XCTFail("expected exhaustion")
        } catch let RepairFailure.exhausted(attempts, history, lastRaw) {
            XCTAssertEqual(attempts, 2)
            XCTAssertEqual(history.count, 2)
            XCTAssertEqual(lastRaw, "bad")
        }

        let stats = await loop.stats
        XCTAssertEqual(stats.exhausted, 1)
        XCTAssertEqual(stats.totalRepairs, 1)

        let events = await recorder.events()
        XCTAssertTrue(events.contains(.exhausted(attempts: 2)))
    }

    func testProducerFailurePropagates() async throws {
        let recorder = InMemoryRepairEventRecorder()
        let loop = OutputRepairLoop(
            contract: validWhenEqual("ok"),
            sleeper: ImmediateSleeper(),
            recorder: recorder
        )
        do {
            _ = try await loop.run(initialPrompt: "prompt", producer: FailingProducer())
            XCTFail("expected producer failure")
        } catch let RepairFailure.producerFailed(attempt, message) {
            XCTAssertEqual(attempt, 1)
            XCTAssertEqual(message, "boom")
        }

        let stats = await loop.stats
        XCTAssertEqual(stats.producerFailures, 1)

        let events = await recorder.events()
        XCTAssertEqual(events, [.producerFailed(attempt: 1, message: "boom")])
    }

    func testBacksOffBetweenRepairs() async throws {
        let sleeper = RecordingSleeper()
        let loop = OutputRepairLoop(
            contract: validWhenEqual("good"),
            policy: RepairPolicy(
                maxAttempts: 3,
                backoff: RepairBackoff(baseMilliseconds: 100, multiplier: 2, capMilliseconds: 1000)
            ),
            sleeper: sleeper
        )
        let run = try await loop.run(initialPrompt: "prompt", producer: ScriptProducer(["bad", "bad", "good"]))

        XCTAssertEqual(run.attempts, 3)
        let slept = await sleeper.durations()
        XCTAssertEqual(slept, [100, 200])
    }

    func testRunsWithoutRecorder() async throws {
        let loop = OutputRepairLoop(contract: validWhenEqual("ok"), sleeper: ImmediateSleeper())
        let run = try await loop.run(initialPrompt: "prompt", producer: ConstantProducer(reply: "ok"))
        XCTAssertEqual(run.attempts, 1)
        XCTAssertEqual(run.output, "ok")
    }

    func testEventsCarryClockTimestamp() async throws {
        let fixed = Date(timeIntervalSince1970: 4242)
        let recorder = InMemoryRepairEventRecorder()
        let loop = OutputRepairLoop(
            contract: validWhenEqual("ok"),
            sleeper: ImmediateSleeper(),
            clock: FixedRepairClock(fixed: fixed),
            recorder: recorder
        )
        _ = try await loop.run(initialPrompt: "prompt", producer: ConstantProducer(reply: "ok"))

        let stamped = await recorder.timestampedEvents()
        XCTAssertFalse(stamped.isEmpty)
        XCTAssertTrue(stamped.allSatisfy { $0.timestamp == fixed })
    }

    func testSingleAttemptPolicyExhaustsWithoutRepair() async throws {
        let loop = OutputRepairLoop(
            contract: validWhenEqual("never"),
            policy: RepairPolicy(maxAttempts: 1),
            sleeper: ImmediateSleeper()
        )
        do {
            _ = try await loop.run(initialPrompt: "prompt", producer: ConstantProducer(reply: "bad"))
            XCTFail("expected exhaustion")
        } catch let RepairFailure.exhausted(attempts, _, _) {
            XCTAssertEqual(attempts, 1)
        }
        let stats = await loop.stats
        XCTAssertEqual(stats.totalRepairs, 0)
    }
}
