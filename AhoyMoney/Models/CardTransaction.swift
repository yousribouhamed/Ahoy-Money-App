import Foundation

// MARK: - Why a payment was declined

/// Decline reasons the processor sends back on the webhook.
///
/// Four cases carry copy we've written, because each one answers a different
/// version of "can I fix this right now" and a single generic message across all
/// of them is the failure mode. Everything else falls to `.other`, which renders
/// whatever the processor sent — deliberately **not** a mapping table, so a
/// reason we've never seen still reaches the worker instead of being swallowed.
enum DeclineReason: Hashable {
    /// Wallet doesn't hold enough. Fixable: top up.
    case insufficientFunds(short: Decimal)

    /// Hit the limit the worker set themselves. Fixable: raise it, up to the
    /// wallet limit.
    case overCardLimit(limit: Decimal, walletLimit: Decimal)

    /// Hit the limit the employer set on the wallet. Not fixable in the app and
    /// there is no route to ask, so we say when it resets and stop.
    case overWalletLimit(limit: Decimal, resetsOn: Date?)

    /// The worker froze this card. Fixable in one action.
    case cardFrozen

    /// Anything else the processor reports. `message` is rendered as-is.
    case other(code: String, message: String)
}

extension DeclineReason {
    /// First line. Read at a till with someone waiting, so it carries the whole
    /// message on its own.
    var title: String {
        switch self {
        case .insufficientFunds: return "Not enough money"
        case .overCardLimit,
             .overWalletLimit:   return "You've reached this card's limit"
        case .cardFrozen:        return "This card is frozen"
        case .other:             return "Payment declined"
        }
    }

    /// What happened and — where there is one — how to fix it.
    var message: String {
        switch self {
        case let .insufficientFunds(short):
            return "You're AED \(Self.money(short)) short. Top up your wallet and ask them to try the payment again."

        case let .overCardLimit(limit, walletLimit):
            return "You set this card's limit to AED \(Self.money(limit)). You can raise it to AED \(Self.money(walletLimit)), the most your employer allows."

        case let .overWalletLimit(limit, resetsOn):
            let base = "You've spent the AED \(Self.money(limit)) your employer allows. It can't go higher."
            guard let resetsOn else { return base }
            return base + " It resets on \(Self.day(resetsOn))."

        case .cardFrozen:
            return "That's why the payment was declined. Unfreeze it and ask them to try again."

        case let .other(_, message):
            // Never seen this one. Show what the processor said, and if it said
            // nothing useful, at least don't pretend we know.
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "Your bank declined this payment but didn't say why. Try again, or use another way to pay."
                : trimmed
        }
    }

    /// The one thing the worker can do about it, if there is one.
    var action: (label: String, kind: ActionKind)? {
        switch self {
        case .insufficientFunds: return ("Top up", .topUp)
        case .overCardLimit:     return ("Change limit", .changeLimit)
        case .overWalletLimit:   return nil          // nothing to press, by design
        case .cardFrozen:        return ("Unfreeze card", .unfreeze)
        case .other:             return nil
        }
    }

    enum ActionKind: Hashable { case topUp, changeLimit, unfreeze }

    /// True when this is a reason we wrote copy for. Useful in QA — an `.other`
    /// showing up often means a case worth promoting to written copy.
    var isWritten: Bool {
        if case .other = self { return false }
        return true
    }

    private static func money(_ value: Decimal) -> String {
        WalletStore.formatMoney(value)
    }

    private static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }
}

// MARK: - Status

/// Where a payment has got to.
///
/// These words are shared by the card-scoped list **and** the account-level
/// Transactions page — same word, same meaning, both places. Referencing one
/// type from both is what keeps that true without relying on review.
///
/// The word "authorised" is deliberately absent: it's the mechanism, not the
/// thing that affects a worker.
enum TransactionStatus: Hashable {
    case onHold
    case paid
    case failed(DeclineReason)
}

extension TransactionStatus {
    var displayName: String {
        switch self {
        case .onHold: return "On hold"
        case .paid:   return "Paid"
        case .failed: return "Declined"
        }
    }

    /// Said once, on the transaction detail — not on every row.
    ///
    /// A card holds money days before it takes it, and that gap is the thing
    /// most workers here have never had to think about, because a bank transfer
    /// has no equivalent. The sentence ends on the part that affects them.
    static let holdExplainer =
        "Shops take the money in two steps. First they hold it, then a few days later they take it for good. Either way it's already out of your balance."
}

// MARK: - Foreign currency

/// Present only when the payment was made in something other than AED.
///
/// TODO: unconfirmed whether the processor returns the original amount and rate
/// or only the AED figure. Optional until that comes back — if it's AED-only,
/// the detail loses the breakdown rather than the whole row.
struct FXDetail: Hashable {
    var originalAmount: Decimal
    var currencyCode: String
    var rate: Decimal?
}

// MARK: - Transaction

/// One payment on one card.
///
/// Scoping is native on the processor call, so this is fetched per card rather
/// than filtered from an account-wide list.
struct CardTransaction: Identifiable, Hashable {
    let id: UUID
    let cardId: UUID
    var merchant: String
    var amount: Decimal          // always AED, the worker's currency
    var fx: FXDetail?            // set when the payment was international
    var status: TransactionStatus
    var date: Date

    init(
        id: UUID = UUID(),
        cardId: UUID,
        merchant: String,
        amount: Decimal,
        fx: FXDetail? = nil,
        status: TransactionStatus,
        date: Date
    ) {
        self.id = id
        self.cardId = cardId
        self.merchant = merchant
        self.amount = amount
        self.fx = fx
        self.status = status
        self.date = date
    }

    var isInternational: Bool { fx != nil }

    var declineReason: DeclineReason? {
        if case let .failed(reason) = status { return reason }
        return nil
    }
}

// MARK: - Store

/// Card-scoped transactions.
///
/// Lists are polled on app open, not streamed — `lastRefreshed` is what lets the
/// UI say when this was true rather than implying it's live. Declines arrive
/// separately as webhook events, which is why they can be read at a till while
/// the list itself is not live.
@Observable
final class CardTransactionStore {
    var transactions: [CardTransaction] = []
    var isLoading: Bool = false
    var lastRefreshed: Date? = nil

    func transactions(for cardId: UUID) -> [CardTransaction] {
        transactions
            .filter { $0.cardId == cardId }
            .sorted { $0.date > $1.date }
    }

    func hasAny(for cardId: UUID) -> Bool {
        transactions.contains { $0.cardId == cardId }
    }

    /// Demo content for a seeded card, covering every state the list has to
    /// render: settled, held, international, and a decline of each written kind.
    static func seed(for cardId: UUID) -> [CardTransaction] {
        let now = Date()
        func ago(_ days: Int, _ hours: Int = 0) -> Date {
            Calendar.current.date(byAdding: DateComponents(day: -days, hour: -hours), to: now) ?? now
        }
        return [
            CardTransaction(cardId: cardId, merchant: "Carrefour",
                            amount: 142.50, status: .paid, date: ago(0, 3)),
            CardTransaction(cardId: cardId, merchant: "Netflix",
                            amount: 39.00, status: .onHold, date: ago(0, 6)),
            CardTransaction(cardId: cardId, merchant: "Amazon.com",
                            amount: 118.75,
                            fx: FXDetail(originalAmount: 32.30, currencyCode: "USD", rate: 3.6725),
                            status: .paid, date: ago(2)),
            CardTransaction(cardId: cardId, merchant: "Talabat",
                            amount: 64.00,
                            status: .failed(.insufficientFunds(short: 45.00)), date: ago(3)),
            CardTransaction(cardId: cardId, merchant: "Apple",
                            amount: 8.00, status: .paid, date: ago(4))
        ]
    }
}
