import Foundation

/// Why an `OutputRepairLoop.run` gave up.
///
/// A repair loop has exactly two ways to fail: the model kept returning
/// unusable output until the attempt budget ran out (`exhausted`), or the thing
/// producing the output threw before any output existed to validate
/// (`producerFailed`). Both carry enough context — the full issue history, the
/// last raw reply, the attempt index — for a caller to log, alert, or fall
/// back without re-deriving what happened.
public enum RepairFailure: Error, Sendable, Equatable {
    /// The attempt budget was spent and the output was still invalid.
    /// `issueHistory` holds the `RepairIssue`s from every failed attempt in
    /// order; `lastRaw` is the final rejected reply.
    case exhausted(attempts: Int, issueHistory: [[RepairIssue]], lastRaw: String)

    /// The producer threw on attempt `attempt`; `message` is its description.
    case producerFailed(attempt: Int, message: String)
}

extension RepairFailure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .exhausted(attempts, issueHistory, _):
            let lastCount = issueHistory.last?.count ?? 0
            return "Output still invalid after \(attempts) attempt(s); "
                + "\(lastCount) unresolved issue(s) on the final attempt."
        case let .producerFailed(attempt, message):
            return "Producer failed on attempt \(attempt): \(message)"
        }
    }
}
