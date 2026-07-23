/// The seam the repair loop drives to get raw output for a prompt — the point
/// where a real model plugs in.
///
/// `ProviderGatewayKit`'s `LLMSession.send(...)` is the intended production
/// conformer: wrap a routed session so the loop can re-prompt it, and the two
/// compose without either depending on the other at compile time. In tests and
/// demos a scripted producer stands in, returning a fixed sequence of replies
/// so the loop's convergence is deterministic. `produce` is `async throws` so
/// a network call — and its failures — flow through naturally, surfacing as
/// `RepairFailure.producerFailed`.
public protocol ResponseProducing: Sendable {
    func produce(prompt: String) async throws -> String
}
