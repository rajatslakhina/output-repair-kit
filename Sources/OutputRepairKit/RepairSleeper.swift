import Foundation

/// The delay seam between a rejected attempt and the next call. Injectable so
/// tests run instantly (a no-op sleeper) while production actually backs off —
/// the same reason `RetryPolicyKit` keeps its sleep behind a protocol. Without
/// this seam a coverage run of the loop's backoff path would have to sleep for
/// real.
public protocol RepairSleeper: Sendable {
    /// Suspends for `milliseconds`. A non-positive value returns immediately.
    func sleep(milliseconds: Int) async throws
}

/// The production sleeper: suspends the current task for the requested time.
public struct SystemRepairSleeper: RepairSleeper {
    public init() {}

    public func sleep(milliseconds: Int) async throws {
        guard milliseconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}
