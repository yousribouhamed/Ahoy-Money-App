import Foundation
import SwiftUI

// MARK: - Card design catalogue

/// Visual treatments the user can pick when issuing a card.
/// Each design defines a gradient, an accent for the chip / type marks,
/// and the foreground (text) colour so we get good contrast on every variant.
enum CardDesign: String, CaseIterable, Hashable, Identifiable {
    case aurora         // cyan → navy (matches the app)
    case midnight       // pure black w/ blue glow
    case sunset         // orange → magenta
    case forest         // emerald → teal
    case roseGold       // peach → rose with metallic feel
    case carbon         // graphite gradient with subtle texture
    case ocean          // azure → indigo
    case glacier        // off-white → ice (light card)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aurora:    return "Aurora"
        case .midnight:  return "Midnight"
        case .sunset:    return "Sunset"
        case .forest:    return "Forest"
        case .roseGold:  return "Rose Gold"
        case .carbon:    return "Carbon"
        case .ocean:     return "Ocean"
        case .glacier:   return "Glacier"
        }
    }

    /// Two-stop gradient; goes top-leading → bottom-trailing for a soft diagonal sheen.
    var gradient: LinearGradient {
        let pair: (Color, Color) = {
            switch self {
            case .aurora:   return (Color(red: 0.06, green: 0.78, blue: 0.95), Color(red: 0.05, green: 0.16, blue: 0.42))
            case .midnight: return (Color(red: 0.05, green: 0.06, blue: 0.12), Color(red: 0.02, green: 0.02, blue: 0.06))
            case .sunset:   return (Color(red: 1.00, green: 0.51, blue: 0.32), Color(red: 0.88, green: 0.18, blue: 0.55))
            case .forest:   return (Color(red: 0.21, green: 0.78, blue: 0.55), Color(red: 0.04, green: 0.36, blue: 0.40))
            case .roseGold: return (Color(red: 1.00, green: 0.79, blue: 0.74), Color(red: 0.78, green: 0.39, blue: 0.42))
            case .carbon:   return (Color(red: 0.28, green: 0.30, blue: 0.34), Color(red: 0.08, green: 0.08, blue: 0.10))
            case .ocean:    return (Color(red: 0.18, green: 0.46, blue: 0.92), Color(red: 0.07, green: 0.13, blue: 0.45))
            case .glacier:  return (Color(red: 0.95, green: 0.97, blue: 1.00), Color(red: 0.80, green: 0.92, blue: 0.97))
            }
        }()
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Used to draw the chip and contactless glyph — matches each gradient's brightest stop.
    var accent: Color {
        switch self {
        case .aurora:    return Color(red: 0.74, green: 0.93, blue: 1.00)
        case .midnight:  return Color(red: 0.50, green: 0.65, blue: 1.00)
        case .sunset:    return Color(red: 1.00, green: 0.80, blue: 0.55)
        case .forest:    return Color(red: 0.74, green: 0.97, blue: 0.80)
        case .roseGold:  return Color(red: 0.99, green: 0.91, blue: 0.86)
        case .carbon:    return Color(red: 0.78, green: 0.80, blue: 0.84)
        case .ocean:     return Color(red: 0.74, green: 0.85, blue: 1.00)
        case .glacier:   return Color(red: 0.18, green: 0.55, blue: 0.78)
        }
    }

    /// Foreground (text + brand mark) colour with adequate contrast against the gradient.
    var foreground: Color {
        switch self {
        case .glacier: return Color(red: 0.07, green: 0.13, blue: 0.30)
        case .roseGold: return Color(red: 0.18, green: 0.06, blue: 0.10)
        default: return .white
        }
    }

    /// Soft shadow tint underneath the card on the wallet — matches the design's first stop.
    var shadowTint: Color {
        switch self {
        case .glacier:  return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .midnight: return Color(red: 0.0, green: 0.0, blue: 0.2)
        default:
            // Pull the first colour of the gradient at low opacity.
            return gradient.shadowSeed
        }
    }

    /// Short tagline shown under the swatch on the design picker.
    var tagline: String {
        switch self {
        case .aurora:    return "Signature cyan"
        case .midnight:  return "Stealth black"
        case .sunset:    return "Warm gradient"
        case .forest:    return "Deep emerald"
        case .roseGold:  return "Soft metallic"
        case .carbon:    return "Industrial"
        case .ocean:     return "Deep blue"
        case .glacier:   return "Light & bright"
        }
    }
}

// MARK: - Internal helper

private extension LinearGradient {
    /// Best-effort tint — used for shadow underneath the card.
    /// Falls back to a soft cyan if the gradient isn't introspectable.
    var shadowSeed: Color {
        Color.black.opacity(0.5)
    }
}

// MARK: - Status

/// R0 is virtual-only, and virtual cards are ready the moment they're made —
/// so there is no pending or issuing state. A create call that fails never
/// produces a card, so failure is a transient error in the create flow rather
/// than a status a card can hold.
///
/// `blocked` deliberately does not exist: account-level suspension blocks the
/// whole wallet and every card at once, and belongs to a separate journey.
enum CardStatus: Hashable {
    case active
    case frozen
    case expired
}

// MARK: - Limits

/// How often a spending limit resets.
enum LimitPeriod: String, CaseIterable, Hashable, Identifiable {
    case daily, weekly, monthly, never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .never:   return "Never"
        }
    }
}

/// A limit the **worker** set on one card. It can only ever be lower than the
/// wallet limit their employer set — there is no route in the app to raise it
/// above that, and nothing in the UI may read like a request form.
///
/// `nil` on a card is a real state: the worker hasn't set one, so only the
/// wallet limit applies.
struct CardLimit: Hashable {
    var amount: Decimal
    var period: LimitPeriod
}

/// Spend accumulated against whichever limit is in force.
///
/// `lastRefreshed` exists so the UI can say *when* this number was true.
/// Balances and spend are polled on app open, not streamed, so nothing built
/// on this may imply a live figure.
struct CardSpend: Hashable {
    var amount: Decimal = 0
    var resetsOn: Date? = nil
    var lastRefreshed: Date = Date()
}

// MARK: - Card

/// A single issued virtual card.
///
/// Note what is **not** here: a balance. A wallet holds one balance and every
/// card reaches that same balance, so money lives on `WalletStore` and nowhere
/// else. More cards never means more money.
struct VirtualCard: Identifiable, Hashable {
    let id: UUID
    var label: String                 // e.g. "Travel", "Subscriptions"
    var design: CardDesign
    var status: CardStatus
    var limit: CardLimit?             // worker's own limit; nil = wallet limit only
    var spend: CardSpend
    var last4: String                 // visible without reveal
    var fullNumber: String            // shown only after reveal
    var expiry: String                // e.g. "08/29"
    var cvv: String                   // shown only after reveal
    var cardholderName: String        // embossed on the card
    var issuedAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        design: CardDesign,
        status: CardStatus = .active,
        limit: CardLimit? = nil,
        spend: CardSpend = CardSpend(),
        last4: String,
        fullNumber: String,
        expiry: String,
        cvv: String,
        cardholderName: String,
        issuedAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.design = design
        self.status = status
        self.limit = limit
        self.spend = spend
        self.last4 = last4
        self.fullNumber = fullNumber
        self.expiry = expiry
        self.cvv = cvv
        self.cardholderName = cardholderName
        self.issuedAt = issuedAt
    }

    /// Pretty grouped representation: "1234 5678 9012 3456" → unchanged but with single space groups.
    var formattedNumber: String {
        let digits = fullNumber.filter(\.isNumber)
        return stride(from: 0, to: digits.count, by: 4).map {
            let start = digits.index(digits.startIndex, offsetBy: $0)
            let end = digits.index(start, offsetBy: min(4, digits.count - $0))
            return String(digits[start..<end])
        }.joined(separator: " ")
    }
}

// MARK: - Store

/// What a new card costs the worker.
///
/// Cards are free today but may be priced later, so the create flow always asks
/// the store for a price and renders whatever comes back. Nothing hardcodes
/// "free" at a call site.
enum CardPrice: Hashable {
    case free
    case amount(Decimal)

    var isFree: Bool { self == .free }
}

/// Process-wide store of issued virtual cards. Seeded with one default card so
/// the wallet always has something to show on first run.
extension VirtualCard {
    /// The card that used to be seeded into the store. Kept for demos and
    /// previews, but no longer handed to every new account.
    static var demoSample: VirtualCard {
        VirtualCard(
            label: "Everyday",
            design: .aurora,
            status: .active,
            limit: CardLimit(amount: 2_000, period: .monthly),
            spend: CardSpend(
                amount: 1_320,
                resetsOn: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                lastRefreshed: Date()
            ),
            last4: "4421",
            fullNumber: "4242 4242 4242 4421",
            expiry: "08/29",
            cvv: "342",
            cardholderName: "YOUSRI BOUHAMED"
        )
    }
}

@Observable
final class VirtualCardStore {
    /// Cards cost us money to issue, so a worker can hold only so many.
    /// Provisional — the final number is the PO's call, so it lives here rather
    /// than as a literal at the call sites.
    var maxCards: Int = 3

    /// Price of issuing the next card. Free for now.
    var priceOfNextCard: CardPrice = .free

    /// Empty by default. A card is never issued automatically — the customer
    /// makes one, which is why the dashboard has a card-shaped empty slot
    /// rather than artwork for a card nobody asked for.
    var cards: [VirtualCard] = []

    /// A worker can always make another card until they hit the cap.
    var canCreateCard: Bool { cards.count < maxCards }

    /// How many slots are left. Named rather than computed at the call sites so
    /// the at-limit copy can say the number instead of implying it.
    var slotsRemaining: Int { max(0, maxCards - cards.count) }

    /// Issuing talks to the processor and can fail.
    ///
    /// Modelled as a seam, like the identity check: the real call replaces
    /// `issue` and nothing else moves. Failure is never terminal here — a card
    /// that didn't issue can always be tried again, which is why there's no
    /// cooldown and no support route on that screen.
    enum IssueOutcome {
        case issued(VirtualCard)
        /// The processor refused or never answered. The customer sees one
        /// message and one button; the reason is for us, not for them.
        case failed
    }

    /// Swapped for the processor call when it exists.
    var issuer: CardIssuer = MockCardIssuer()

    func issue(label: String, design: CardDesign, cardholderName: String) async -> IssueOutcome {
        guard canCreateCard else { return .failed }
        let outcome = await issuer.issue(
            label: label, design: design, cardholderName: cardholderName
        )
        if case let .issued(card) = outcome { add(card) }
        return outcome
    }

    /// Inserts at the top so the just-issued card is featured first.
    func add(_ card: VirtualCard) {
        cards.insert(card, at: 0)
    }

    /// Deleting is permanent and is **never** blocked — not even on the last
    /// card. A worker who deletes everything lands on the empty state and can
    /// make another, which is also how they change their card number.
    func remove(_ card: VirtualCard) {
        cards.removeAll { $0.id == card.id }
    }

    func update(_ card: VirtualCard) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i] = card
    }

    func setStatus(_ card: VirtualCard, _ status: CardStatus) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i].status = status
    }

    func toggleFreeze(_ card: VirtualCard) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i].status = (cards[i].status == .frozen) ? .active : .frozen
    }

    // MARK: - Edits the worker can make any time

    func rename(_ card: VirtualCard, to label: String) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        cards[i].label = trimmed.isEmpty ? cards[i].label : String(trimmed.prefix(24))
    }

    func setDesign(_ card: VirtualCard, to design: CardDesign) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i].design = design
    }

    /// Sets the worker's own limit on a card, clamped so it can never exceed the
    /// wallet limit their employer set. Pass `nil` to clear it, which leaves only
    /// the wallet limit in force.
    func setLimit(_ card: VirtualCard, to limit: CardLimit?, walletLimit: Decimal) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        guard var limit else {
            cards[i].limit = nil
            return
        }
        limit.amount = min(limit.amount, walletLimit)
        cards[i].limit = limit
    }

    /// Generates a random-but-stable demo card. Real implementation would call the issuer API.
    static func makeMockCard(label: String, design: CardDesign, cardholderName: String) -> VirtualCard {
        let last4 = String(format: "%04d", Int.random(in: 1000...9999))
        let bin = "4242"
        let middle = "\(Int.random(in: 1000...9999)) \(Int.random(in: 1000...9999))"
        let full = "\(bin) \(middle) \(last4)"
        let cvv = String(format: "%03d", Int.random(in: 100...999))
        let year = Calendar.current.component(.year, from: Date()) % 100 + 5
        let month = Int.random(in: 1...12)
        let expiry = String(format: "%02d/%02d", month, year)
        return VirtualCard(
            label: label.isEmpty ? "Virtual card" : label,
            design: design,
            limit: nil,          // no worker limit yet — the wallet limit applies
            spend: CardSpend(),
            last4: last4,
            fullNumber: full,
            expiry: expiry,
            cvv: cvv,
            cardholderName: cardholderName.uppercased()
        )
    }
}

// MARK: - Issuer

/// The processor call that mints a card, behind a protocol.
///
/// Issuing is instant when it works — there is no queue and nothing to wait
/// for, so no screen in this flow may promise a time. What it can do is fail,
/// and that's the only reason this seam exists.
protocol CardIssuer {
    func issue(
        label: String,
        design: CardDesign,
        cardholderName: String
    ) async -> VirtualCardStore.IssueOutcome
}

/// Stand-in until the processor is wired up.
struct MockCardIssuer: CardIssuer {
    /// Set to drive the failure state while testing it.
    var alwaysFails: Bool = false

    func issue(
        label: String,
        design: CardDesign,
        cardholderName: String
    ) async -> VirtualCardStore.IssueOutcome {
        try? await Task.sleep(for: .milliseconds(700))
        if alwaysFails { return .failed }
        return .issued(
            VirtualCardStore.makeMockCard(
                label: label, design: design, cardholderName: cardholderName
            )
        )
    }
}
