import Foundation
@testable import OutputRepairKit

/// A closure-driven `OutputContract` so each test can decide validity inline.
struct StubContract: OutputContract {
    let check: @Sendable (String) -> ContractResult<String>

    func validate(_ raw: String) -> ContractResult<String> {
        check(raw)
    }
}

/// A contract that accepts only an exact string, rejecting everything else with
/// a single issue.
func validWhenEqual(_ target: String) -> StubContract {
    StubContract { raw in
        raw == target
            ? .valid(raw)
            : .invalid([RepairIssue(path: "v", problem: "expected \(target)", observed: raw)])
    }
}

/// Always returns the same reply, regardless of prompt.
struct ConstantProducer: ResponseProducing {
    let reply: String

    func produce(prompt: String) async throws -> String {
        reply
    }
}

/// Always throws before producing anything.
struct FailingProducer: ResponseProducing {
    struct Boom: Error, CustomStringConvertible {
        let description = "boom"
    }

    func produce(prompt: String) async throws -> String {
        throw Boom()
    }
}

/// Returns a scripted sequence of replies (repeating the last once exhausted)
/// and records the prompts it was handed.
actor ScriptProducer: ResponseProducing {
    private let replies: [String]
    private var index = 0
    private var prompts: [String] = []

    init(_ replies: [String]) {
        self.replies = replies
    }

    func produce(prompt: String) async throws -> String {
        prompts.append(prompt)
        let reply = replies[Swift.min(index, replies.count - 1)]
        index += 1
        return reply
    }

    func receivedPrompts() -> [String] {
        prompts
    }
}

/// A sleeper that never actually sleeps — keeps loop tests instant.
struct ImmediateSleeper: RepairSleeper {
    func sleep(milliseconds: Int) async throws {}
}

/// A sleeper that records the delays it was asked for instead of sleeping.
actor RecordingSleeper: RepairSleeper {
    private var slept: [Int] = []

    func sleep(milliseconds: Int) async throws {
        slept.append(milliseconds)
    }

    func durations() -> [Int] {
        slept
    }
}

/// A `RepairClock` pinned to a fixed instant for deterministic timestamps.
struct FixedRepairClock: RepairClock {
    let fixed: Date
    var now: Date { fixed }
}
