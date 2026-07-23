import Foundation
import OutputRepairKit

// MARK: - The output we want, and the contract that validates it

/// The structured value the demo insists the model return.
struct WeatherReport: Codable, Equatable {
    let city: String
    let tempC: Int
    let condition: String
}

/// Validates a raw reply into a `WeatherReport`, collecting *every* problem in
/// one pass so a single repair round can fix all of them. In production this is
/// exactly where a `StructuredOutputKit` schema decoder would sit.
struct WeatherContract: OutputContract {
    func validate(_ raw: String) -> ContractResult<WeatherReport> {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            return .invalid([RepairIssue(path: "", problem: "not a JSON object", observed: raw)])
        }

        var issues: [RepairIssue] = []
        let city = dict["city"] as? String
        if city == nil {
            issues.append(RepairIssue(path: "city", problem: "missing or not a string", expected: "string"))
        }
        let tempC = dict["tempC"] as? Int
        if tempC == nil {
            let observed = dict["tempC"].map { "\($0)" }
            issues.append(RepairIssue(
                path: "tempC",
                problem: "missing or not an integer",
                expected: "integer",
                observed: observed
            ))
        }
        let condition = dict["condition"] as? String
        if condition == nil || condition?.isEmpty == true {
            issues.append(RepairIssue(path: "condition", problem: "missing or empty", expected: "non-empty string"))
        }

        guard issues.isEmpty, let city, let tempC, let condition else {
            return .invalid(issues)
        }
        return .valid(WeatherReport(city: city, tempC: tempC, condition: condition))
    }
}

// MARK: - Stand-in producers (a real one would wrap ProviderGatewayKit's LLMSession)

struct ProducerError: Error, CustomStringConvertible {
    let description: String
}

/// Returns a fixed sequence of replies — a scripted "model" that improves after
/// each correction — and records the prompts it was handed, so the demo can
/// show the real repair prompt the loop generated.
actor ScriptedProducer: ResponseProducing {
    private let replies: [String]
    private var index = 0
    private var receivedPrompts: [String] = []

    init(replies: [String]) {
        self.replies = replies
    }

    func produce(prompt: String) async throws -> String {
        receivedPrompts.append(prompt)
        guard !replies.isEmpty else { return "" }
        let reply = replies[Swift.min(index, replies.count - 1)]
        index += 1
        return reply
    }

    func prompts() -> [String] {
        receivedPrompts
    }
}

/// A producer whose model call itself fails, before any output exists.
struct ThrowingProducer: ResponseProducing {
    let error: ProducerError

    func produce(prompt: String) async throws -> String {
        throw error
    }
}

// MARK: - Scenarios

func demoConverge(_ loop: OutputRepairLoop<WeatherContract>) async throws {
    print("--- 1. converge: a model that fixes its JSON once told exactly what is wrong ---")
    let producer = ScriptedProducer(replies: [
        #"{"city": "Delhi"}"#,
        #"{"city": "Delhi", "tempC": "hot", "condition": "Sunny"}"#,
        #"{"city": "Delhi", "tempC": 41, "condition": "Sunny"}"#
    ])
    let prompt = "Report Delhi's current weather as JSON with keys city, tempC, condition."
    let run = try await loop.run(initialPrompt: prompt, producer: producer)
    print("  attempts: \(run.attempts)   repairs: \(run.repairs)")
    print("  decoded:  \(run.output)")
    print("  issues seen per failed attempt:")
    for (round, issues) in run.issueHistory.enumerated() {
        let paths = issues.map(\.path).joined(separator: ", ")
        print("    attempt \(round + 1): \(issues.count) issue(s) -> [\(paths)]")
    }

    let prompts = await producer.prompts()
    if prompts.count > 1 {
        print("\n  the repair prompt the loop sent after attempt 1:")
        for line in prompts[1].split(separator: "\n", omittingEmptySubsequences: false) {
            print("    | \(line)")
        }
    }
}

func demoExhaust(_ loop: OutputRepairLoop<WeatherContract>) async throws {
    print("\n--- 2. exhaust: a model that never fixes it, stopped by the attempt budget ---")
    let producer = ScriptedProducer(replies: [#"{"city": "Delhi"}"#])
    do {
        _ = try await loop.run(initialPrompt: "Report Delhi's weather as JSON.", producer: producer)
        print("  unexpectedly succeeded")
    } catch let failure as RepairFailure {
        print("  gave up: \(failure.errorDescription ?? "\(failure)")")
    }
}

func demoProducerFailure(_ loop: OutputRepairLoop<WeatherContract>) async throws {
    print("\n--- 3. producer failure: the model call itself throws, surfaced verbatim ---")
    let producer = ThrowingProducer(error: ProducerError(description: "simulated 503 from provider"))
    do {
        _ = try await loop.run(initialPrompt: "anything", producer: producer)
    } catch let failure as RepairFailure {
        print("  gave up: \(failure.errorDescription ?? "\(failure)")")
    }
}

func demoStats(_ loop: OutputRepairLoop<WeatherContract>) async {
    print("\n--- 4. stats: the loop actor accumulates health signal across all three runs ---")
    let stats = await loop.stats
    print("  totalRuns: \(stats.totalRuns)   succeeded: \(stats.succeeded)   "
        + "exhausted: \(stats.exhausted)   producerFailures: \(stats.producerFailures)")
    print("  totalRepairs across finished runs: \(stats.totalRepairs)")
}

func label(for event: RepairEvent) -> String {
    switch event {
    case .produced: return "produced"
    case .validated: return "validated"
    case .invalid: return "invalid"
    case .repairScheduled: return "repairScheduled"
    case .exhausted: return "exhausted"
    case .producerFailed: return "producerFailed"
    }
}

func demoAuditTrail(_ recorder: InMemoryRepairEventRecorder) async {
    print("\n--- 5. audit trail: every attempt, rejection, repair, and outcome recorded ---")
    let events = await recorder.events()
    var counts: [String: Int] = [:]
    for event in events {
        counts[label(for: event), default: 0] += 1
    }
    let summary = counts.sorted { $0.key < $1.key }
        .map { "\($0.key): \($0.value)" }
        .joined(separator: ", ")
    print("  \(events.count) events -> \(summary)")
}

func demoBackoffSchedule() {
    print("\n--- 6. backoff: an exponential, capped, deterministic repair schedule ---")
    let backoff = RepairBackoff(baseMilliseconds: 200, multiplier: 2, capMilliseconds: 1000)
    let schedule = (1...5).map { "\($0):\(backoff.delayMilliseconds(forRetry: $0))ms" }
    print("  base 200ms x2, cap 1000ms -> " + schedule.joined(separator: "  "))
}

@main
struct Demo {
    static func main() async throws {
        print("== OutputRepairKit demo ==\n")
        let recorder = InMemoryRepairEventRecorder()
        let loop = OutputRepairLoop(
            contract: WeatherContract(),
            policy: RepairPolicy(maxAttempts: 4),
            recorder: recorder
        )
        try await demoConverge(loop)
        try await demoExhaust(loop)
        try await demoProducerFailure(loop)
        await demoStats(loop)
        await demoAuditTrail(recorder)
        demoBackoffSchedule()
    }
}
