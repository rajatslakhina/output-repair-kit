/// One structured reason an LLM's output was rejected by an `OutputContract`.
///
/// A repair loop is only as good as the feedback it sends back: the 2026
/// literature on LLM repair loops ("structured feedback improves repair") is
/// consistent that *what failed, where, and what was expected* — not a bare
/// "invalid" — is what lets the next attempt actually converge. `RepairIssue`
/// is that structured feedback as a value type: a `path` into the output, a
/// human-readable `problem`, and the optional `expected`/`observed` pair that
/// turns "wrong" into "wrong how".
///
/// It is deliberately format-agnostic — `path` is just a string, so it fits a
/// JSON pointer (`tempC`), a field name, an XML path, or a free-form location.
public struct RepairIssue: Sendable, Equatable, CustomStringConvertible {
    /// Where in the output the problem is, e.g. a field name or JSON path.
    /// Empty when the problem is about the output as a whole (e.g. "not JSON").
    public let path: String

    /// A short, human-readable description of what is wrong.
    public let problem: String

    /// What a valid output should have had here, if known.
    public let expected: String?

    /// What the output actually had here, if known.
    public let observed: String?

    public init(
        path: String,
        problem: String,
        expected: String? = nil,
        observed: String? = nil
    ) {
        self.path = path
        self.problem = problem
        self.expected = expected
        self.observed = observed
    }

    /// A one-line rendering suitable for embedding in a repair prompt, e.g.
    /// `tempC: wrong type (expected integer, observed "hot")`.
    public var description: String {
        let head = path.isEmpty ? problem : "\(path): \(problem)"
        var qualifiers: [String] = []
        if let expected {
            qualifiers.append("expected \(expected)")
        }
        if let observed {
            qualifiers.append("observed \(observed)")
        }
        return qualifiers.isEmpty ? head : "\(head) (\(qualifiers.joined(separator: ", ")))"
    }
}
