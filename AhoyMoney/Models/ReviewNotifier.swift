import Foundation
import UserNotifications

/// Tells the customer their review has finished.
///
/// The under-review screen promises "We'll notify you the moment it's done",
/// and until now nothing kept that promise. A review clearing is a back-office
/// event, so the real thing is a **remote** push sent when a reviewer decides —
/// there is no way to schedule it from the device, because the device doesn't
/// know when the decision will land.
///
/// This is the seam that push slots into. `LocalReviewNotifier` posts the same
/// notification locally so the behaviour is demonstrable and the copy can be
/// agreed before a backend exists; swapping in an APNs-backed implementation
/// means writing one type and changing nothing else.
protocol ReviewNotifier {
    /// Ask once, at the point the promise is made. Returns whether we may post.
    @discardableResult
    func requestPermission() async -> Bool

    /// The review finished. `approved` picks which of the two messages to send.
    func reviewCleared(approved: Bool) async

    /// The customer is no longer waiting — drop anything still pending so a
    /// decision they've already seen can't arrive twice.
    func cancelPending() async
}

/// Stand-in until push exists.
///
/// Posts a local notification with the wording the real push should use, so the
/// copy is reviewable now rather than being written twice.
struct LocalReviewNotifier: ReviewNotifier {
    /// One identifier, so a second decision replaces the first rather than
    /// stacking a contradictory pair in Notification Centre.
    private static let identifier = "ahoy.review.cleared"

    @discardableResult
    func requestPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        // Asking twice is a no-op at the system level, but checking first keeps
        // us from re-prompting someone who already said no.
        let settings = await centre.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await centre.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func reviewCleared(approved: Bool) async {
        let centre = UNUserNotificationCenter.current()
        guard await requestPermission() else { return }

        let content = UNMutableNotificationContent()
        if approved {
            content.title = "Your wallet is open"
            content.body = "The check is done. Tap to start using Ahoy."
        } else {
            // Never states the outcome. A decline is not something to learn
            // from a lock screen in front of other people, and the reason
            // can't be shared anyway.
            content.title = "We've finished checking"
            content.body = "Tap to see where your application stands."
        }
        content.sound = .default

        // No trigger — deliver now. The caller decides when "now" is, which in
        // production is the push arriving rather than anything on the device.
        try? await centre.add(
            UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil)
        )
    }

    func cancelPending() async {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        centre.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

/// No-op, for previews and tests — a `#Preview` should never trip a permission
/// prompt.
struct SilentReviewNotifier: ReviewNotifier {
    @discardableResult
    func requestPermission() async -> Bool { true }
    func reviewCleared(approved: Bool) async {}
    func cancelPending() async {}
}
