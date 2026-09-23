import Foundation

/// What the identity check hands back.
///
/// Modelled on uqudo's shape without depending on it: the document is read, the
/// face is matched against it, and either it passes with a set of read fields or
/// it fails in one of two ways that mean very different things downstream.
enum IdentityCheckResult {
    /// Passed. Carries the fields read off the Emirates ID.
    case passed(IdentityDetails)

    /// The face didn't match the document. The customer is still inside the
    /// journey — this is a retry, not an exit.
    case captureFailed

    /// An automatic control stopped it: an expired or unreadable document, a
    /// sanctions match, a prohibited jurisdiction. No queue and no reviewer,
    /// and the reason must never reach the customer.
    case refused
}

/// The identity check, behind a protocol.
///
/// The uqudo SDK isn't installed — it's distributed privately and needs
/// credentials and a licence key. This is the seam it slots into: implement
/// this one type against the SDK and nothing else in the app changes.
///
/// The capture screens themselves belong to the vendor, so nothing here draws
/// them; this only models what comes back.
protocol IdentityVerifier {
    func verify() async -> IdentityCheckResult
}

/// Stand-in until the SDK is available.
///
/// Returns a scanned Emirates ID so the rest of the journey — Fill Details, the
/// edit-triggers-review branch, the four exits — is walkable without it.
struct MockIdentityVerifier: IdentityVerifier {
    /// Set to drive a particular outcome while testing a state.
    var outcome: IdentityCheckResult = .passed(.scannedSample)

    func verify() async -> IdentityCheckResult {
        try? await Task.sleep(for: .seconds(1.5))
        return outcome
    }
}

extension OnboardingStore {
    /// Runs the check and moves the store to whichever of the three outcomes
    /// came back. Keeps the mapping in one place rather than at the call site.
    func runIdentityCheck(using verifier: IdentityVerifier) async {
        switch await verifier.verify() {
        case let .passed(details):
            identity = details
            identityPassed()
        case .captureFailed:
            identityFailed()
        case .refused:
            systemRefuse()
        }
    }
}
