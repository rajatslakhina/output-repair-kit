import Foundation

/// The clock an `OutputRepairLoop` reads when stamping `RepairEvent`s.
/// Injectable so tests and demos can pin event timestamps deterministically
/// instead of depending on wall-clock time — the same seam
/// `SemanticRouterKit.RouterClock` and `AgentMemoryKit.MemoryClock` expose.
public protocol RepairClock: Sendable {
    var now: Date { get }
}

/// The production clock: reads the real current time.
public struct SystemRepairClock: RepairClock {
    public init() {}

    public var now: Date { Date() }
}
