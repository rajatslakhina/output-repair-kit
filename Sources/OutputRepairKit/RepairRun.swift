/// The successful result of an `OutputRepairLoop.run`: the trusted decoded
/// `output`, plus the story of how many rounds it took to get there.
public struct RepairRun<Output: Sendable>: Sendable {
    /// The validated value the winning attempt decoded to.
    public let output: Output

    /// How many producer calls it took, including the first (>= 1).
    public let attempts: Int

    /// The `RepairIssue`s from each *failed* attempt, in order. Empty when the
    /// very first attempt validated.
    public let issueHistory: [[RepairIssue]]

    /// The raw reply that finally validated.
    public let finalRaw: String

    /// How many repair round trips happened before success (`attempts - 1`).
    public var repairs: Int {
        Swift.max(0, attempts - 1)
    }

    public init(output: Output, attempts: Int, issueHistory: [[RepairIssue]], finalRaw: String) {
        self.output = output
        self.attempts = attempts
        self.issueHistory = issueHistory
        self.finalRaw = finalRaw
    }
}

/// Running totals an `OutputRepairLoop` accumulates across every `run` it
/// serves — the loop is an actor precisely so these stay consistent under
/// concurrent callers. Cheap fleet-wide health signal: a rising `exhausted`
/// share means a prompt or model that repair can no longer save.
public struct RepairStats: Sendable, Equatable {
    /// Total `run` calls started.
    public var totalRuns: Int
    /// Runs that ended with a valid output.
    public var succeeded: Int
    /// Runs that spent the attempt budget still invalid.
    public var exhausted: Int
    /// Runs that ended because the producer threw.
    public var producerFailures: Int
    /// Sum of repair round trips across all finished runs.
    public var totalRepairs: Int

    public init(
        totalRuns: Int = 0,
        succeeded: Int = 0,
        exhausted: Int = 0,
        producerFailures: Int = 0,
        totalRepairs: Int = 0
    ) {
        self.totalRuns = totalRuns
        self.succeeded = succeeded
        self.exhausted = exhausted
        self.producerFailures = producerFailures
        self.totalRepairs = totalRepairs
    }
}
