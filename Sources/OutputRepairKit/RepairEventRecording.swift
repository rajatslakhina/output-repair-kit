import Foundation

/// An audit sink for `RepairEvent`s. Attach one to an `OutputRepairLoop` to
/// capture every attempt, rejection, repair, and terminal outcome. Optional: a
/// loop with no recorder simply skips emission — the same opt-in event seam
/// `SemanticRouterKit` and `TraceKit` expose.
public protocol RepairEventRecording: Sendable {
    func record(_ event: RepairEvent, at timestamp: Date) async
}

/// An in-memory `RepairEventRecording` that keeps every event, in order, with
/// its timestamp — useful for tests, demos, and lightweight local inspection.
public actor InMemoryRepairEventRecorder: RepairEventRecording {
    private var recorded: [TimestampedRepairEvent] = []

    public init() {}

    public func record(_ event: RepairEvent, at timestamp: Date) async {
        recorded.append(TimestampedRepairEvent(event: event, timestamp: timestamp))
    }

    /// Every recorded event, without timestamps, in order.
    public func events() -> [RepairEvent] {
        recorded.map(\.event)
    }

    /// Every recorded event with its timestamp, in order.
    public func timestampedEvents() -> [TimestampedRepairEvent] {
        recorded
    }

    public var count: Int {
        recorded.count
    }
}
