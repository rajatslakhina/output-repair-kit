/// How long the loop waits between a rejected attempt and the next one.
///
/// Re-prompting an LLM immediately after a rejection is fine for a local model
/// but hammers a rate-limited hosted endpoint; an exponential, capped backoff
/// is the standard courtesy. The schedule is expressed in whole milliseconds
/// with an integer `multiplier` so it is exact and fully deterministic — no
/// floating-point drift, no jitter to make tests flaky. Every field is clamped
/// to a sane range at construction, so a `RepairBackoff` can never produce a
/// negative or runaway delay.
public struct RepairBackoff: Sendable, Equatable {
    /// The delay before the first repair, in milliseconds (clamped to >= 0).
    public let baseMilliseconds: Int

    /// The per-retry growth factor (clamped to >= 1). `1` is a constant delay.
    public let multiplier: Int

    /// The maximum delay, in milliseconds. `0` means "no cap".
    public let capMilliseconds: Int

    public init(baseMilliseconds: Int, multiplier: Int = 2, capMilliseconds: Int = 0) {
        self.baseMilliseconds = Swift.max(0, baseMilliseconds)
        self.multiplier = Swift.max(1, multiplier)
        self.capMilliseconds = Swift.max(0, capMilliseconds)
    }

    /// No delay at all — the default. Re-prompts fire back to back.
    public static let none = RepairBackoff(baseMilliseconds: 0)

    /// The delay before the repair that follows attempt number `retry`
    /// (`retry` is 1-based: the wait after the first failure is `forRetry: 1`).
    /// Saturating: once the schedule reaches the cap it stays there, and an
    /// arithmetic overflow is treated as reaching the cap.
    public func delayMilliseconds(forRetry retry: Int) -> Int {
        guard baseMilliseconds > 0, retry >= 1 else { return 0 }
        let cap = capMilliseconds > 0 ? capMilliseconds : Int.max
        var delay = Swift.min(baseMilliseconds, cap)
        var step = 1
        while step < retry {
            let (next, overflow) = delay.multipliedReportingOverflow(by: multiplier)
            delay = (overflow || next > cap) ? cap : next
            step += 1
        }
        return delay
    }
}
