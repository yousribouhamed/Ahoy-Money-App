import Foundation
import SwiftUI

// MARK: - Categories

/// Fintech-appropriate help categories. Each carries its own icon, gradient,
/// and one-line description so the picker can be visually rich without us
/// hand-tuning each tile.
enum HelpCategory: String, CaseIterable, Identifiable, Hashable {
    case gettingStarted
    case wallet
    case cards
    case transfers
    case security
    case fees
    case disputes
    case legal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .wallet:         return "Wallet & Balance"
        case .cards:          return "Cards"
        case .transfers:      return "Transfers & Beneficiaries"
        case .security:       return "Security & Privacy"
        case .fees:           return "Fees & Limits"
        case .disputes:       return "Disputes & Refunds"
        case .legal:          return "Legal & Compliance"
        }
    }

    /// Short tagline shown on the category tile under the title.
    var tagline: String {
        switch self {
        case .gettingStarted: return "Setup, verification, KYC"
        case .wallet:         return "Top up, balance, FX"
        case .cards:          return "Virtual cards, freezing"
        case .transfers:      return "Send money worldwide"
        case .security:       return "Face ID, 2FA, fraud"
        case .fees:           return "Pricing, daily limits"
        case .disputes:       return "Refunds, chargebacks"
        case .legal:          return "Terms, privacy, T&Cs"
        }
    }

    var icon: String {
        switch self {
        case .gettingStarted: return "sparkles"
        case .wallet:         return "wallet.bifold.fill"
        case .cards:          return "creditcard.fill"
        case .transfers:      return "arrow.left.arrow.right"
        case .security:       return "lock.shield.fill"
        case .fees:           return "chart.pie.fill"
        case .disputes:       return "exclamationmark.bubble.fill"
        case .legal:          return "doc.text.fill"
        }
    }

    /// Distinctive duo per category. Light, readable on dark bg, used as a
    /// gradient across the icon tile.
    var gradient: LinearGradient {
        let pair: (Color, Color) = {
            switch self {
            case .gettingStarted: return (Color(red: 0.06, green: 0.78, blue: 0.95), Color(red: 0.31, green: 0.42, blue: 0.95))
            case .wallet:         return (Color(red: 0.34, green: 0.85, blue: 0.55), Color(red: 0.07, green: 0.50, blue: 0.42))
            case .cards:          return (Color(red: 1.00, green: 0.51, blue: 0.32), Color(red: 0.88, green: 0.18, blue: 0.55))
            case .transfers:      return (Color(red: 0.50, green: 0.45, blue: 1.00), Color(red: 0.20, green: 0.20, blue: 0.65))
            case .security:       return (Color(red: 0.18, green: 0.46, blue: 0.92), Color(red: 0.07, green: 0.13, blue: 0.45))
            case .fees:           return (Color(red: 1.00, green: 0.79, blue: 0.30), Color(red: 0.85, green: 0.45, blue: 0.10))
            case .disputes:       return (Color(red: 1.00, green: 0.42, blue: 0.55), Color(red: 0.78, green: 0.10, blue: 0.30))
            case .legal:          return (Color(red: 0.62, green: 0.65, blue: 0.72), Color(red: 0.30, green: 0.32, blue: 0.40))
            }
        }()
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Soft tint used behind the category card on dark mode.
    var tint: Color {
        switch self {
        case .gettingStarted: return Color(red: 0.06, green: 0.78, blue: 0.95)
        case .wallet:         return Color(red: 0.34, green: 0.85, blue: 0.55)
        case .cards:          return Color(red: 1.00, green: 0.51, blue: 0.32)
        case .transfers:      return Color(red: 0.50, green: 0.45, blue: 1.00)
        case .security:       return Color(red: 0.18, green: 0.46, blue: 0.92)
        case .fees:           return Color(red: 1.00, green: 0.79, blue: 0.30)
        case .disputes:       return Color(red: 1.00, green: 0.42, blue: 0.55)
        case .legal:          return Color(red: 0.78, green: 0.80, blue: 0.86)
        }
    }
}

// MARK: - Article

/// A single help-center entry.
///
/// `answer` accepts plain text or simple Markdown — the article view renders
/// `**bold**`, `*italic*`, lists (`- `), and link-style emphasis. Each article
/// also carries `relatedIds` so we can surface contextual follow-ups at the
/// bottom of the article view.
struct HelpArticle: Identifiable, Hashable {
    let id: UUID
    let category: HelpCategory
    let question: String
    let answer: String
    var isPopular: Bool
    var relatedIds: [UUID]
    /// Optional read-time hint, in minutes. We show it as "2 min read" if set.
    var readTime: Int?

    init(
        id: UUID = UUID(),
        category: HelpCategory,
        question: String,
        answer: String,
        isPopular: Bool = false,
        relatedIds: [UUID] = [],
        readTime: Int? = nil
    ) {
        self.id = id
        self.category = category
        self.question = question
        self.answer = answer
        self.isPopular = isPopular
        self.relatedIds = relatedIds
        self.readTime = readTime
    }
}

// MARK: - Store

/// Process-wide help-center store. Pre-seeded with content covering every
/// category so the search and category screens have meaningful results.
@Observable
final class HelpStore {
    var articles: [HelpArticle]
    var recentSearches: [String] = []
    var trendingTopics: [String] = [
        "How to top up", "Freeze card", "International transfer fees",
        "Face ID not working", "Verify my account"
    ]

    init() {
        // Seed articles. We define them in order, then enrich popular flags
        // and `relatedIds` after creation so we can cross-reference IDs.
        var seeded: [HelpArticle] = []

        // ─── Getting Started ──────────────────────────────────────────────
        seeded.append(.init(
            category: .gettingStarted,
            question: "How do I create an Ahoy wallet?",
            answer: """
            Tap **Create account** on the welcome screen and follow the four-step setup:

            - Enter your name, email and phone
            - Verify your email and phone with a 6-digit code
            - Scan your Emirates ID (front + back) and take a quick selfie
            - Set a wallet password and enable Face ID

            The whole flow takes about 3 minutes. We'll text you the moment your account is approved — usually within minutes.
            """,
            isPopular: true,
            readTime: 2
        ))
        seeded.append(.init(
            category: .gettingStarted,
            question: "What documents do I need to verify my identity?",
            answer: """
            For UAE residents we need:

            - A valid Emirates ID (front and back)
            - A clear selfie that matches the ID photo

            For visitors, an in-date passport works in place of the Emirates ID. Make sure all four corners are visible and there's no glare.
            """,
            readTime: 1
        ))
        seeded.append(.init(
            category: .gettingStarted,
            question: "How long does verification take?",
            answer: """
            Most accounts are verified automatically in **under 5 minutes**. If our automatic checks need a closer look, a real person reviews your documents — that can take up to 24 hours on weekdays. You'll get a push notification either way.
            """,
            readTime: 1
        ))
        seeded.append(.init(
            category: .gettingStarted,
            question: "Why was my application declined?",
            answer: """
            Applications are usually declined for one of three reasons:

            - The ID photo is blurry, cropped, or expired
            - The selfie doesn't match the ID photo
            - You're under 18 — minimum age in the UAE is 18

            You can re-submit immediately. If you've tried twice and it still fails, tap **Contact us** at the bottom of this screen and we'll resolve it.
            """,
            readTime: 2
        ))

        // ─── Wallet & Balance ─────────────────────────────────────────────
        seeded.append(.init(
            category: .wallet,
            question: "How do I top up my wallet?",
            answer: """
            From the Wallet tab, tap the **+** button next to your balance. You can top up using:

            - Apple Pay (instant)
            - Debit / credit card (instant, 0.9% fee on non-AED cards)
            - Bank transfer (free, arrives within 1 working day)

            Top-ups above AED 5,000 require Face ID confirmation as a security check.
            """,
            isPopular: true,
            readTime: 1
        ))
        seeded.append(.init(
            category: .wallet,
            question: "Why is my balance lower than expected?",
            answer: """
            A few common causes:

            - **Pending transactions** that haven't settled yet — they're already deducted from your available balance.
            - **Card holds** — when you swipe at a hotel or rental car, an authorisation hold can sit for up to 7 days before being released.
            - **Currency conversion** — transactions in non-AED currencies are converted at the live mid-market rate plus a small margin.

            Check your transaction list — pending items show a clock icon next to the amount.
            """,
            readTime: 2
        ))
        seeded.append(.init(
            category: .wallet,
            question: "Can I hold multiple currencies?",
            answer: """
            Right now Ahoy holds AED only. Multi-currency wallets (USD, EUR, GBP) are coming later this year — you can pre-register from **Settings → Coming soon**.
            """,
            readTime: 1
        ))
        seeded.append(.init(
            category: .wallet,
            question: "How do exchange rates work?",
            answer: """
            We use the **mid-market rate** — the same one you'll find on Google or Reuters. We add a transparent margin of 0.5% on most currencies and 1.5% on weekend / public holiday conversions. The exact rate is shown before you confirm any FX transaction.
            """,
            readTime: 2
        ))

        // ─── Cards ────────────────────────────────────────────────────────
        seeded.append(.init(
            category: .cards,
            question: "How do I issue a virtual card?",
            answer: """
            From the Wallet tab, tap **Get Virtual Card**, accept the cardholder agreement, then:

            1. Pick a design (8 to choose from)
            2. Name your card (e.g. "Travel" or "Subscriptions")
            3. Confirm with Face ID

            Your card is ready instantly — no shipping wait.
            """,
            isPopular: true,
            readTime: 1
        ))
        seeded.append(.init(
            category: .cards,
            question: "How many cards can I have?",
            answer: """
            You can hold up to **5 active virtual cards** at once. The first card is free. Each additional card costs AED 5 — a small fee that helps deter abuse and keeps the platform safe for everyone.
            """,
            readTime: 1
        ))
        seeded.append(.init(
            category: .cards,
            question: "How do I freeze a card?",
            answer: """
            Open the card from the Wallet tab and tap **Freeze**. The card is disabled for new transactions instantly — recurring subscriptions and merchant holds will fail until you unfreeze.

            Unfreezing is just as fast — tap the same button. No Face ID needed because the action is reversible.
            """,
            isPopular: true,
            readTime: 1
        ))
        seeded.append(.init(
            category: .cards,
            question: "What's the difference between freezing and blocking?",
            answer: """
            **Freeze** is reversible — useful if you've misplaced your phone for a few hours, or want to pause subscriptions.

            **Block** is permanent — the card number is dead and can't be reactivated. Use it if you suspect fraud. Any remaining balance is returned to your wallet, and you can issue a fresh card immediately.
            """,
            readTime: 2
        ))
        seeded.append(.init(
            category: .cards,
            question: "Can I add my virtual card to Apple Pay?",
            answer: """
            Yes. From the card detail screen, tap **Add to Apple Pay**. After Face ID confirmation, the card is provisioned to your default Wallet — usually in a few seconds.
            """,
            readTime: 1
        ))

        // ─── Transfers & Beneficiaries ────────────────────────────────────
        seeded.append(.init(
            category: .transfers,
            question: "How do I send money to someone?",
            answer: """
            Open the **Send** tab and pick a destination:

            - **Ahoy Wallet** — instant, free, by phone or Ahoy ID
            - **UAE Bank Account** — same-day, AED 1 fee
            - **International** — to 200+ countries, fees shown before you confirm

            Select an existing beneficiary or tap **+ New Beneficiary** to add one. All transfers require Face ID.
            """,
            isPopular: true,
            readTime: 2
        ))
        seeded.append(.init(
            category: .transfers,
            question: "How long do international transfers take?",
            answer: """
            Most international transfers arrive in **1–2 working days**. SWIFT routing through correspondent banks can occasionally add another day, especially for currencies like INR, PHP, or PKR. The exact ETA is shown before you confirm.
            """,
            readTime: 2
        ))
        seeded.append(.init(
            category: .transfers,
            question: "How do I edit or delete a beneficiary?",
            answer: """
            Open **Send → Beneficiaries**, tap the contact, then use the **⋯** menu in the top-right.

            Heavier edits (changing the underlying phone number, IBAN, or SWIFT) intentionally aren't allowed — those require deleting the beneficiary and adding a new one. This protects you against social engineering.
            """,
            readTime: 1
        ))
        seeded.append(.init(
            category: .transfers,
            question: "I sent money to the wrong person — can I get it back?",
            answer: """
            **Wallet-to-wallet transfers** can be reversed if the recipient hasn't yet spent the money. Go to your transactions, tap the transfer, then **Request reversal**.

            **Bank transfers** can't be unilaterally reversed — we'll need the recipient's agreement to send the funds back. Contact us immediately and we'll do our best to help.
            """,
            readTime: 2
        ))

        // ─── Security ─────────────────────────────────────────────────────
        seeded.append(.init(
            category: .security,
            question: "How do I enable Face ID?",
            answer: """
            Go to **Settings → Security** and toggle **Biometric Authentication**. You'll be asked to verify with Face ID once to confirm — after that, every sensitive action (sending money, revealing card details, changing passwords) is gated by your face.
            """,
            isPopular: true,
            readTime: 1
        ))
        seeded.append(.init(
            category: .security,
            question: "What is two-factor authentication?",
            answer: """
            Two-factor authentication (2FA) adds a second layer beyond your password. We support:

            - **Face ID** (default for all sensitive actions)
            - **6-digit SMS code** (used when you log in from a new device)

            We don't yet support hardware keys, but we're working on it.
            """,
            readTime: 1
        ))
        seeded.append(.init(
            category: .security,
            question: "Someone has access to my account — what should I do?",
            answer: """
            Act immediately:

            1. Open **Settings → Security → Sign out from all devices**
            2. Change your password
            3. Block all your virtual cards (Wallet → tap card → Block)
            4. Tap **Contact us** below — our fraud team works 24/7

            We'll freeze the account, investigate, and refund any unauthorised transactions per UAE Central Bank rules.
            """,
            readTime: 2
        ))
        seeded.append(.init(
            category: .security,
            question: "Is Ahoy safe? Where is my money held?",
            answer: """
            Ahoy is regulated by the **UAE Central Bank**. Your funds sit in segregated client-money accounts at top-tier UAE banks — they're never used for our operating expenses, and they remain yours even in the unlikely event Ahoy goes out of business.
            """,
            readTime: 2
        ))

        // ─── Fees & Limits ────────────────────────────────────────────────
        seeded.append(.init(
            category: .fees,
            question: "How much does Ahoy cost?",
            answer: """
            Most things are **free**:

            - Account opening
            - Wallet-to-wallet transfers
            - First virtual card

            Paid items are clearly marked before you confirm:

            - International transfers: 0.4% (min AED 5)
            - Additional virtual cards: AED 5 each
            - Non-AED card spend: 0.5% FX margin

            See the full **Schedule of Fees** under Legal & Compliance.
            """,
            readTime: 2
        ))
        seeded.append(.init(
            category: .fees,
            question: "What are my daily and monthly limits?",
            answer: """
            Default limits for verified accounts:

            - **Send**: AED 30,000 / day, AED 150,000 / month
            - **Top up**: AED 50,000 / day
            - **Card spend**: AED 25,000 / month per card

            You can adjust card limits from **Settings → Transfer Limits**. To raise wallet-level limits, contact us with your use case.
            """,
            readTime: 2
        ))

        // ─── Disputes & Refunds ───────────────────────────────────────────
        seeded.append(.init(
            category: .disputes,
            question: "How do I dispute a transaction?",
            answer: """
            Open the transaction from your activity list and tap **Dispute**. You'll be asked:

            - Why you're disputing (fraud, duplicate, didn't receive goods, etc.)
            - Any supporting evidence (receipts, screenshots, emails)

            We'll open a case immediately and update you within 1 working day. Card disputes can take up to 60 days under Visa rules — but a provisional credit is usually issued within 5 days.
            """,
            readTime: 3
        ))
        seeded.append(.init(
            category: .disputes,
            question: "How long do refunds take?",
            answer: """
            Most refunds appear within **3–5 working days**. Some merchants take longer to process — once they confirm the refund, it usually lands in your wallet within 24 hours.

            If it's been more than 7 days, tap the original transaction → **Where's my refund?** and we'll chase it on your behalf.
            """,
            readTime: 1
        ))

        // ─── Legal ────────────────────────────────────────────────────────
        seeded.append(.init(
            category: .legal,
            question: "Where can I read the Cardholder Agreement?",
            answer: """
            The full cardholder agreement, privacy notice, and schedule of fees are all available in-app at **Settings → Legal**, and on our website at ahoy.ae/legal. They're also emailed to you when you accept them during card issuance.
            """,
            readTime: 1
        ))
        seeded.append(.init(
            category: .legal,
            question: "How do I close my account?",
            answer: """
            We're sorry to see you go. To close:

            1. Withdraw any remaining balance to a UAE bank account
            2. Block any active virtual cards
            3. Tap **Contact us** and request closure

            We'll keep your data for 5 years as required by UAE AML regulations, but the account will be permanently deactivated.
            """,
            readTime: 2
        ))

        self.articles = seeded

        // After-the-fact wiring of related articles by topic similarity.
        wireRelatedArticles()
    }

    private func wireRelatedArticles() {
        // Cards: freeze ↔ block + multiple cards.
        if let freeze = articles.firstIndex(where: { $0.question.contains("freeze a card") }),
           let block = articles.firstIndex(where: { $0.question.contains("freezing and blocking") }),
           let multi = articles.firstIndex(where: { $0.question.contains("How many cards") })
        {
            articles[freeze].relatedIds = [articles[block].id, articles[multi].id]
            articles[block].relatedIds = [articles[freeze].id, articles[multi].id]
        }
        // Transfers: send + wrong person + edit beneficiary.
        if let send = articles.firstIndex(where: { $0.question.contains("How do I send money") }),
           let wrong = articles.firstIndex(where: { $0.question.contains("wrong person") }),
           let edit = articles.firstIndex(where: { $0.question.contains("edit or delete a beneficiary") })
        {
            articles[send].relatedIds = [articles[edit].id, articles[wrong].id]
        }
    }

    // MARK: - Queries

    func popular() -> [HelpArticle] {
        articles.filter(\.isPopular)
    }

    func articles(in category: HelpCategory) -> [HelpArticle] {
        articles.filter { $0.category == category }
    }

    /// Case- and diacritic-insensitive search across question + answer.
    /// Ranks question-matches above answer-matches.
    func search(_ query: String) -> [HelpArticle] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let scored: [(article: HelpArticle, score: Int)] = articles.compactMap { a in
            let ql = a.question.lowercased()
            let al = a.answer.lowercased()
            if ql.contains(q) { return (a, 3) }
            if ql.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return (a, 2) }
            if al.contains(q) { return (a, 1) }
            return nil
        }
        return scored
            .sorted { $0.score > $1.score }
            .map(\.article)
    }

    func recordSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // De-dup, push to the front, cap at 8.
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 8 { recentSearches = Array(recentSearches.prefix(8)) }
    }

    func article(by id: UUID) -> HelpArticle? {
        articles.first(where: { $0.id == id })
    }

    func related(to article: HelpArticle, limit: Int = 3) -> [HelpArticle] {
        let direct = article.relatedIds.compactMap { id in articles.first { $0.id == id } }
        if direct.count >= limit { return Array(direct.prefix(limit)) }
        // Fill from same category, excluding self + already-included.
        let excluded = Set([article.id] + direct.map(\.id))
        let extra = articles
            .filter { $0.category == article.category && !excluded.contains($0.id) }
            .prefix(limit - direct.count)
        return direct + Array(extra)
    }
}
