/// Everything the repair loop knows about a rejected attempt, handed to a
/// `RepairPrompting` so it can compose the correction to send next.
public struct RepairContext: Sendable, Equatable {
    /// The original prompt the loop started with, unchanged across attempts.
    public let originalPrompt: String

    /// The raw reply that was just rejected.
    public let lastRaw: String

    /// Why it was rejected — one `RepairIssue` per problem found.
    public let issues: [RepairIssue]

    /// The 1-based index of the attempt that was just rejected.
    public let attempt: Int

    public init(originalPrompt: String, lastRaw: String, issues: [RepairIssue], attempt: Int) {
        self.originalPrompt = originalPrompt
        self.lastRaw = lastRaw
        self.issues = issues
        self.attempt = attempt
    }
}

/// Builds the correction prompt sent after a rejected attempt. Swapping this is
/// how a caller tunes the *repair* prompt independently of the *original* one —
/// terser feedback for a small model, stricter wording for a stubborn one.
public protocol RepairPrompting: Sendable {
    func repairPrompt(_ context: RepairContext) -> String
}

/// The default correction prompt: restate the goal, quote the rejected reply,
/// enumerate every issue as structured feedback, and demand only the corrected
/// output back. This mirrors what the repair-loop literature finds most
/// effective — failure location plus observed-vs-expected, not a bare "try
/// again".
public struct DefaultRepairPrompter: RepairPrompting {
    public init() {}

    public func repairPrompt(_ context: RepairContext) -> String {
        var lines: [String] = []
        lines.append(context.originalPrompt)
        lines.append("")
        lines.append("Your previous reply was rejected. It was:")
        lines.append(context.lastRaw)
        lines.append("")
        lines.append("Fix exactly these \(context.issues.count) problem(s):")
        for (index, issue) in context.issues.enumerated() {
            lines.append("  \(index + 1). \(issue.description)")
        }
        lines.append("")
        lines.append("Return only the corrected output, with no explanation.")
        return lines.joined(separator: "\n")
    }
}
