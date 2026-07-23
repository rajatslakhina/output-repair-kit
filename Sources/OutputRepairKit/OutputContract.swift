/// The validation seam the repair loop drives: given the raw text an LLM
/// returned, either decode it into a trusted `Output` value or explain, as a
/// list of `RepairIssue`s, exactly why it was rejected.
///
/// This is the point where `StructuredOutputKit`'s schema-validated decoding
/// plugs in — wrap a schema decoder in an `OutputContract` and the loop will
/// re-prompt until the decode succeeds or the attempt budget runs out. Keeping
/// it a protocol (rather than depending on `StructuredOutputKit` at compile
/// time) matches the no-hard-dependency convention every kit in this series
/// follows, and lets a caller validate with anything: `Codable`, a regex, a
/// business-rule predicate, or a real JSON-schema validator.
public protocol OutputContract: Sendable {
    /// The trusted, decoded value a valid output produces.
    associatedtype Output: Sendable

    /// Validates one raw output. Returns `.valid` with the decoded value, or
    /// `.invalid` with every issue found — collecting *all* problems in one
    /// pass gives the repair prompt more to correct per round trip than
    /// surfacing them one at a time.
    func validate(_ raw: String) -> ContractResult<Output>
}

/// The result of validating one raw output against an `OutputContract`.
public enum ContractResult<Output: Sendable>: Sendable {
    /// The output decoded cleanly into a trusted value.
    case valid(Output)

    /// The output was rejected; each `RepairIssue` explains one reason.
    case invalid([RepairIssue])
}
