import Foundation
import LocalAuthentication

/// Lightweight wrapper around `LAContext` for Face ID / Touch ID prompts.
enum BiometricAuth {
    /// Request authentication. Calls `completion` on the main thread.
    ///
    /// Biometric is attempted on its own first. The device passcode is only
    /// offered when biometric can't be met — either because the device has none
    /// enrolled, or because the biometric attempt failed.
    ///
    /// This previously returned `success = true` whenever the device couldn't
    /// evaluate a biometric policy, which meant card number and CVV revealed
    /// with no authentication at all on a phone with Face ID switched off.
    static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        #if targetEnvironment(simulator)
        // Simulators have no enrolled biometric and no usable passcode, so the
        // strict path below leaves every dev flow stuck on a prompt that can't
        // be answered. Scoped to simulator builds only — devices always take
        // the real path.
        DispatchQueue.main.async { completion(true) }
        #else
        let context = LAContext()
        // Suppress the system's own fallback button; we escalate deliberately.
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometric available — go straight to passcode rather than
            // letting the caller through.
            authenticateWithPasscode(reason: reason, completion: completion)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evaluationError in
            if success {
                DispatchQueue.main.async { completion(true) }
                return
            }

            // The worker cancelled — that's a decision, not a failed check, so
            // don't escalate and don't nag.
            if let laError = evaluationError as? LAError,
               laError.code == .userCancel || laError.code == .appCancel || laError.code == .systemCancel {
                DispatchQueue.main.async { completion(false) }
                return
            }

            // Biometric couldn't be met for any other reason — offer passcode.
            authenticateWithPasscode(reason: reason, completion: completion)
        }
        #endif
    }

    /// Device passcode, used only as the escalation from biometric.
    private static func authenticateWithPasscode(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on the device either. Refuse — this guards card
            // number and CVV, so failing closed is the only safe outcome.
            DispatchQueue.main.async { completion(false) }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
