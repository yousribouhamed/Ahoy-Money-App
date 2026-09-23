import Foundation
import UserNotifications

/// Tells the worker a payment was declined.
///
/// **Read at the till.** Every decline arrives from the processor as a webhook,
/// becomes a push, and lands as a row in the card's history. The push is the
/// one people actually read, and they read it standing at a counter with a
/// queue behind them — so it has to answer one question in a glance: *can I fix
/// this right now?*
///
/// That's why the body is `DeclineReason.detail` rather than a generic string.
/// The four written reasons each say something different; the fallback carries
/// whatever the processor sent.
protocol DeclineNotifier {
    @discardableResult
    func requestPermission() async -> Bool
    func declined(merchant: String, amount: Decimal, reason: DeclineReason) async
}

struct LocalDeclineNotifier: DeclineNotifier {
    @discardableResult
    func requestPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let settings = await centre.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined:
            return (try? await centre.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default: return false
        }
    }

    func declined(merchant: String, amount: Decimal, reason: DeclineReason) async {
        let centre = UNUserNotificationCenter.current()
        guard await requestPermission() else { return }

        let content = UNMutableNotificationContent()
        // The title names the shop and the amount, so it's recognisable without
        // opening anything — that alone tells them which payment failed.
        content.title = "\(merchant) · AED \(WalletStore.formatMoney(amount)) declined"
        // `message` already answers "can I fix this now?" per reason, and the
        // `.other` case carries whatever the processor sent — so an unseen
        // reason still renders somewhere sensible instead of a generic line.
        content.body = reason.message
        content.sound = .default
        // Unique per decline: two failed payments are two events, and collapsing
        // them would hide the second attempt someone just made.
        content.userInfo = ["kind": "decline"]

        try? await centre.add(
            UNNotificationRequest(
                identifier: "ahoy.decline." + UUID().uuidString,
                content: content,
                trigger: nil
            )
        )
    }
}

/// No-op, for previews and tests.
struct SilentDeclineNotifier: DeclineNotifier {
    @discardableResult
    func requestPermission() async -> Bool { true }
    func declined(merchant: String, amount: Decimal, reason: DeclineReason) async {}
}

extension CardTransactionStore {
    /// A decline arriving from the processor.
    ///
    /// One event, two destinations — the history row and the push — because a
    /// worker who dismissed the notification still needs to find out what
    /// happened, and a worker who never opens the app still needs telling.
    func recordDecline(
        cardId: UUID,
        merchant: String,
        amount: Decimal,
        reason: DeclineReason,
        notifier: DeclineNotifier = LocalDeclineNotifier()
    ) {
        let tx = CardTransaction(
            cardId: cardId,
            merchant: merchant,
            amount: amount,
            status: .failed(reason),
            date: Date()
        )
        transactions.insert(tx, at: 0)
        Task { await notifier.declined(merchant: merchant, amount: amount, reason: reason) }
    }
}
