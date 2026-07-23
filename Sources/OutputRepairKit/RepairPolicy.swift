/// The budget an `OutputRepairLoop` runs under: how many times it may call the
/// producer, and how long it waits between calls.
///
/// The attempt budget is the whole point of a *bounded* repair loop — the 2026
/// repair-loop studies converge on a small ceiling (three is a commonly cited
/// sweet spot) because a model that has not produced valid output in a few
/// structured-feedback rounds rarely does on the tenth, and the tokens are not
/// free. `maxAttempts` is clamped to at least 1, so a loop always makes at
/// least one call.
public struct RepairPolicy: Sendable, Equatable {
    /// Total producer calls allowed, including the first (clamped to >= 1).
    /// `maxAttempts` of `N` means one initial attempt plus up to `N - 1`
    /// repairs.
    public let maxAttempts: Int

    /// The wait schedule between a rejected attempt and the next call.
    public let backoff: RepairBackoff

    public init(maxAttempts: Int = 3, backoff: RepairBackoff = .none) {
        self.maxAttempts = Swift.max(1, maxAttempts)
        self.backoff = backoff
    }
}
