import Foundation

/// One recorded moment in a repair loop's life, emitted to a
/// `RepairEventRecording` sink when one is attached. Together they form an
/// auditable trace of exactly how an output was produced: how many times the
/// model was called, what was wrong each round, how long the loop backed off,
/// and whether it converged or gave up. Useful for offline analysis of which
/// prompts need the most repair.
public enum RepairEvent: Sendable, Equatable {
    /// The producer returned a raw reply on this attempt (before validation).
    case produced(attempt: Int)

    /// The reply on this attempt validated cleanly; the loop succeeds.
    case validated(attempt: Int)

    /// The reply on this attempt was rejected for these reasons.
    case invalid(attempt: Int, issues: [RepairIssue])

    /// A repair was scheduled after a rejected attempt, waiting
    /// `delayMilliseconds` before the next call.
    case repairScheduled(attempt: Int, delayMilliseconds: Int)

    /// The attempt budget was spent; the loop gives up after this many attempts.
    case exhausted(attempts: Int)

    /// The producer threw on this attempt; the loop gives up.
    case producerFailed(attempt: Int, message: String)
}

/// A `RepairEvent` paired with the instant it was recorded. The timestamp comes
/// from the loop's injected `RepairClock`, so it is deterministic in tests.
public struct TimestampedRepairEvent: Sendable, Equatable {
    public let event: RepairEvent
    public let timestamp: Date

    public init(event: RepairEvent, timestamp: Date) {
        self.event = event
        self.timestamp = timestamp
    }
}
