import Foundation
import SwiftUI

@Observable
final class WalletStore {
    /// The one balance. Every card reaches this same money — cards do not hold
    /// balances of their own, so this is the only place spendable money lives.
    var balance: Double = 0
    var isAccountVerified: Bool = false

    // MARK: - Employer limit
    //
    // Set by the worker's employer, applies across the whole wallet, and is the
    // ceiling every card sits under. The worker cannot change it and there is no
    // route in the app to ask for more — so nothing built on this may read like
    // a request form.
    //
    // Card limits do not add up against this: three cards at AED 2,000 each
    // still cannot spend past the wallet number.

    var employerLimit: Decimal = 5_000
    var employerLimitPeriod: LimitPeriod = .monthly
    var employerSpent: Decimal = 0
    var employerLimitResetsOn: Date? = Calendar.current.date(
        byAdding: .month, value: 1, to: Date()
    )

    /// How much of the wallet limit is left this period.
    var employerLimitRemaining: Decimal {
        max(0, employerLimit - employerSpent)
    }

    /// Bridge for card screens, which work in `Decimal`.
    ///
    /// TODO: `balance` should itself be `Decimal` — `Double` is the wrong type
    /// for money. Pre-existing, and a separate change from the card work.
    var balanceDecimal: Decimal {
        Decimal(balance)
    }

    /// The limit actually in force on a card: the worker's own if they set one,
    /// otherwise the wallet limit. Never above the wallet limit either way.
    func effectiveLimit(for card: VirtualCard) -> (amount: Decimal, period: LimitPeriod, isWalletLimit: Bool) {
        guard let own = card.limit else {
            return (employerLimit, employerLimitPeriod, true)
        }
        return (min(own.amount, employerLimit), own.period, false)
    }

    static func formatMoney(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func formatMoney(_ value: Decimal) -> String {
        formatMoney(NSDecimalNumber(decimal: value).doubleValue)
    }
}

@Observable
final class AppRouter {
    enum Route: Hashable {
        case login
        case register
        case verifyOtp
        case setupWallet
        case scanID
        case scanIDBack
        case selfieIntro
        case selfieCapture
        case verifyingIdentity
        case identityFailed
        case systemRefused
        case fillDetails
        case setPasscode
        case walletCreated
        /// Opened automatically once the wallet is approved — the worker picks
        /// the colour and the name rather than us inventing them.
        case createFirstCard
        case heldForReview
        case forgetPassword
        case resetPassword
    }

    enum Tab: Hashable { case wallet, send, transactions, settings }

    var authPath: [Route] = []

    /// Set by the arrival screen when the customer chose "Create your card".
    /// The dashboard picks it up on appear and opens the flow, so the request
    /// survives the hop out of the auth stack.
    var pendingCardCreation: Bool = false
    var isAuthenticated: Bool = false
    var selectedTab: Tab = .wallet
}
