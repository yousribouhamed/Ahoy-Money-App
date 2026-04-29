import Foundation
import LocalAuthentication

/// Lightweight wrapper around `LAContext` for Face ID / Touch ID prompts.
enum BiometricAuth {
    /// Request biometric authentication. Calls `completion` on the main thread.
    /// On simulators or devices without biometrics, falls back to `success = true` so dev flows aren't blocked.
    static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics available — allow through (e.g. simulator without enrolled Face ID).
            DispatchQueue.main.async { completion(true) }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
