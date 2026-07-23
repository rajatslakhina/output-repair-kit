/// A bounded, self-healing repair loop for structured LLM output.
///
/// The pattern the 2026 applied-AI literature settled on (Pydantic AI's
/// output-validator retries, Instructor's `max_retries`, VeriHarness's
/// validator-controlled loop): call a model, validate the reply against a
/// contract, and if it fails, send the *structured reasons* back and try
/// again — up to a small budget. Not a bare "please try again", but "field
/// `tempC` should be an integer, you sent \"hot\"". Structured feedback is
/// what makes these loops actually converge.
///
/// `OutputRepairLoop` is that loop as a reusable actor. It owns no model of its
/// own — the model is the `ResponseProducing` passed to `run`, which in
/// production wraps a `ProviderGatewayKit` `LLMSession`. It owns no schema of
/// its own either — validation is the `OutputContract`, which in production
/// wraps a `StructuredOutputKit` decoder. The loop only orchestrates: produce,
/// validate, feed back, back off, repeat, and stop — converged or exhausted.
/// It is an `actor` so the `RepairStats` it accumulates across runs stay
/// consistent under concurrent callers.
public actor OutputRepairLoop<Contract: OutputContract> {
    /// The trusted value type this loop's contract decodes to.
    public typealias Output = Contract.Output

    private let contract: Contract
    private let prompter: RepairPrompting
    private let policy: RepairPolicy
    private let sleeper: RepairSleeper
    private let clock: RepairClock
    private let recorder: RepairEventRecording?
    private var _stats = RepairStats()

    public init(
        contract: Contract,
        prompter: RepairPrompting = DefaultRepairPrompter(),
        policy: RepairPolicy = RepairPolicy(),
        sleeper: RepairSleeper = SystemRepairSleeper(),
        clock: RepairClock = SystemRepairClock(),
        recorder: RepairEventRecording? = nil
    ) {
        self.contract = contract
        self.prompter = prompter
        self.policy = policy
        self.sleeper = sleeper
        self.clock = clock
        self.recorder = recorder
    }

    /// Running totals across every `run` this loop has served.
    public var stats: RepairStats {
        _stats
    }

    /// Drives the loop for one output. Calls `producer` with `initialPrompt`,
    /// validates the reply, and on rejection re-prompts with structured
    /// feedback until a reply validates or the attempt budget is spent.
    ///
    /// - Returns: a `RepairRun` with the decoded output and how many rounds it
    ///   took.
    /// - Throws: `RepairFailure.exhausted` if the budget runs out still
    ///   invalid, or `RepairFailure.producerFailed` if `producer` throws.
    public func run<Producer: ResponseProducing>(
        initialPrompt: String,
        producer: Producer
    ) async throws -> RepairRun<Output> {
        _stats.totalRuns += 1
        return try await attempt(
            1,
            prompt: initialPrompt,
            initialPrompt: initialPrompt,
            history: [],
            producer: producer
        )
    }

    /// One turn of the loop: produce, validate, and either succeed, give up, or
    /// recurse into the next attempt. Recursion (rather than an unbounded
    /// `while`) keeps every exit an explicit `return`/`throw`, so the loop has
    /// no unreachable fall-through.
    private func attempt<Producer: ResponseProducing>(
        _ number: Int,
        prompt: String,
        initialPrompt: String,
        history: [[RepairIssue]],
        producer: Producer
    ) async throws -> RepairRun<Output> {
        let raw: String
        do {
            raw = try await producer.produce(prompt: prompt)
        } catch {
            _stats.producerFailures += 1
            let message = String(describing: error)
            await emit(.producerFailed(attempt: number, message: message))
            throw RepairFailure.producerFailed(attempt: number, message: message)
        }
        await emit(.produced(attempt: number))

        switch contract.validate(raw) {
        case let .valid(output):
            _stats.succeeded += 1
            _stats.totalRepairs += number - 1
            await emit(.validated(attempt: number))
            return RepairRun(output: output, attempts: number, issueHistory: history, finalRaw: raw)

        case let .invalid(issues):
            var updatedHistory = history
            updatedHistory.append(issues)
            await emit(.invalid(attempt: number, issues: issues))

            guard number < policy.maxAttempts else {
                _stats.exhausted += 1
                _stats.totalRepairs += number - 1
                await emit(.exhausted(attempts: number))
                throw RepairFailure.exhausted(attempts: number, issueHistory: updatedHistory, lastRaw: raw)
            }

            let delay = policy.backoff.delayMilliseconds(forRetry: number)
            if delay > 0 {
                try await sleeper.sleep(milliseconds: delay)
            }
            let repairPrompt = prompter.repairPrompt(RepairContext(
                originalPrompt: initialPrompt,
                lastRaw: raw,
                issues: issues,
                attempt: number
            ))
            await emit(.repairScheduled(attempt: number, delayMilliseconds: delay))
            return try await attempt(
                number + 1,
                prompt: repairPrompt,
                initialPrompt: initialPrompt,
                history: updatedHistory,
                producer: producer
            )
        }
    }

    private func emit(_ event: RepairEvent) async {
        await recorder?.record(event, at: clock.now)
    }
}
