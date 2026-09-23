import SwiftUI

/// The full detail view for a single virtual card.
///
/// Layout:
/// • Top bar — back, "Card", more menu (rename, change design, terminate)
/// • Hero — `CardArtwork` with 3D tilt; tap to flip for the security code
/// • Balance + monthly spend progress
/// • Quick action row — Top Up, Freeze/Unfreeze, Details
/// • Recent transactions
/// • Block (terminate) button — destructive
///
/// All mutations round-trip through `VirtualCardStore` so the wallet & list
/// stay in sync.
struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VirtualCardStore.self) private var store
    @Environment(WalletStore.self) private var wallet
    // No `AppRouter` any more — the Send tile was its only reader.
    @Environment(CardTransactionStore.self) private var cardTransactions

    let cardId: UUID

    /// Which card is on screen. Starts at the one that was tapped, then follows
    /// the worker as they swipe.
    @State private var selectedCardId: UUID

    @State private var revealed: Bool = false

    /// Which way up the hero card is. The security code is on the back, so
    /// this is how you get to it.
    @State private var flipped: Bool = false

    /// How long revealed details stay on screen before hiding themselves.
    static let revealSeconds = 60
    @State private var secondsLeft: Int = revealSeconds
    private let revealTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showDeleteConfirm: Bool = false
    @State private var showRename: Bool = false
    @State private var showChangeDesign: Bool = false
    @State private var showLimitEditor: Bool = false
    @State private var pushedTransaction: CardTransaction? = nil
    @State private var declinedTransaction: CardTransaction? = nil
    @State private var showTopUp: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    init(cardId: UUID) {
        self.cardId = cardId
        _selectedCardId = State(initialValue: cardId)
    }

    /// Latest copy from the store so freeze / rename / etc. reflect live.
    ///
    /// Falls back to the first card because deleting the card you're looking at
    /// pops this screen — but the view can re-evaluate once before it goes.
    private var card: VirtualCard {
        store.cards.first(where: { $0.id == selectedCardId })
            ?? store.cards.first(where: { $0.id == cardId })
            ?? store.cards.first!
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 22) {
                    hero
                    balanceCard
                    quickActions
                    transactionsSection
                    blockButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .scrollEdgeBlur()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .padding(.horizontal, 19)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .headerBlurBackground()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Deleting is permanent, has no undo and no toast, so every consequence
        // is stated before the button rather than discovered after it.
        //
        // Deleting is never blocked — not even on the last card. A worker who
        // deletes everything lands on the empty state and makes another, which
        // is also how they change their card number.
        // A bottom sheet, matching the other card controls. The consequences run
        // to three paragraphs — an alert crams them and a confirmation dialog
        // pushed the buttons off-screen entirely.
        .sheet(item: $pushedTransaction) { tx in
            CardTransactionSheet(transaction: tx)
        }
        .sheet(item: $declinedTransaction) { tx in
            if let reason = tx.declineReason {
                DeclineSheet(
                    reason: reason,
                    merchant: tx.merchant,
                    amount: tx.amount
                ) { kind in
                    switch kind {
                    case .topUp:       showTopUp = true
                    case .changeLimit: showLimitEditor = true
                    case .unfreeze:
                        store.setStatus(card, .active)
                        toast("Card unfrozen")
                    }
                }
            }
        }
        .sheet(isPresented: $showTopUp) {
            TopUpView().presentationDragIndicator(.hidden)
        }
        .task(id: card.id) {
            // Demo data stands in for the processor call until it's wired.
            guard !cardTransactions.hasAny(for: card.id), card.spend.amount > 0 else { return }
            cardTransactions.transactions += CardTransactionStore.seed(for: card.id)
            cardTransactions.lastRefreshed = Date()
        }
        .sheet(isPresented: $showDeleteConfirm) {
            DeleteCardSheet {
                store.remove(card)
                dismiss()
            }
        }
        .sheet(isPresented: $showRename) {
            RenameCardSheet(currentName: card.label) { newName in
                store.rename(card, to: newName)
                toast("Card renamed")
            }
        }
        .sheet(isPresented: $showChangeDesign) {
            ChangeDesignSheet(card: card) { design in
                store.setDesign(card, to: design)
                toast("Card colour updated")
            }
        }
        .sheet(isPresented: $showLimitEditor) {
            CardLimitSheet(
                currentLimit: card.limit,
                walletLimit: wallet.employerLimit,
                walletPeriod: wallet.employerLimitPeriod
            ) { newLimit in
                store.setLimit(card, to: newLimit, walletLimit: wallet.employerLimit)
                toast(newLimit == nil ? "Card limit removed" : "Limit updated")
            }
        }
        .liquidGlassToast(
            isPresented: $showToast,
            message: toastMessage,
            duration: 1.8
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Card")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)

                Spacer()

                Menu {
                    Button {
                        showRename = true
                    } label: {
                        Label("Rename card", systemImage: "pencil")
                    }
                    Button {
                        showChangeDesign = true
                    } label: {
                        Label("Change colour", systemImage: "paintpalette")
                    }
                    Button {
                        showLimitEditor = true
                    } label: {
                        Label("Spending limit", systemImage: "gauge.with.dots.needle.50percent")
                    }
                    Divider()
                    if card.status == .frozen {
                        Button {
                            store.toggleFreeze(card)
                            toast("Card unfrozen")
                        } label: {
                            Label("Unfreeze", systemImage: "sun.max")
                        }
                    } else {
                        Button {
                            store.toggleFreeze(card)
                            toast("Card frozen")
                        } label: {
                            Label("Freeze card", systemImage: "snowflake")
                        }
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete card", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
            }
        }
    }

    // MARK: - Hero

    /// Card at the container's full width, holding the artwork's own aspect.
    ///
    /// No status badge underneath: "Active" is the normal case and doesn't need
    /// announcing, and the two states that *do* matter — frozen and expired —
    /// already take over the card art itself.
    private var hero: some View {
        VStack(spacing: 12) {
            Color.clear
                .aspectRatio(340.0 / 212.0, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        // Swiping the card is the way between cards. Everything
                        // below the hero — balance, limit, details, activity —
                        // follows `selectedCardId`, so the whole screen moves
                        // with the swipe rather than just the artwork.
                        TabView(selection: $selectedCardId) {
                            ForEach(store.cards) { c in
                                CardArtwork(
                                    card: c,
                                    size: geo.size,
                                    // Only the card in front can be revealed;
                                    // neighbours never render a live number.
                                    revealed: revealed && c.id == selectedCardId,
                                    tiltEnabled: true,
                                    flipped: flipped && c.id == selectedCardId,
                                    showsIdentity: true
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                                        flipped.toggle()
                                    }
                                }
                                .tag(c.id)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }

            if store.cards.count > 1 {
                pageIndicator
            }

            // Name, status and number are printed on the card now, so the row
            // that used to sit here is gone. What is left is the one thing the
            // artwork cannot say for itself: how to turn it over, and how long
            // the numbers have before they hide again.
            cardFooter
        }
        .padding(.top, 6)
        // Revealed details must not survive a swipe — the number on screen
        // would belong to a card the worker is no longer looking at. Nor
        // should the card stay face-down under a different card's back.
        .onChange(of: selectedCardId) { _, _ in
            withAnimation(.easeOut(duration: 0.2)) {
                revealed = false
                flipped = false
            }
        }
        // The countdown used to live on the details card. That card is gone;
        // the timer still has to run.
        .onReceive(revealTimer) { _ in
            guard revealed else { return }
            if secondsLeft > 1 {
                secondsLeft -= 1
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    revealed = false
                    flipped = false
                }
            }
        }
    }

    /// Flip hint, copy button and hide-countdown — the three things that used
    /// to be spread across a separate details card.
    private var cardFooter: some View {
        HStack(spacing: 10) {
            Label(
                flipped ? "Tap to see the front" : "Tap the card for the CVV",
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textSecondary)

            Spacer(minLength: 0)

            if revealed {
                // Typing a PAN off a screen that is about to blank itself is
                // how digits get transposed, so the copy stays one tap away.
                Button {
                    let value = flipped ? card.cvv : card.fullNumber.filter(\.isNumber)
                    UIPasteboard.general.string = value
                    toast(flipped ? "Security code copied" : "Card number copied")
                } label: {
                    Label(flipped ? "Copy CVV" : "Copy number", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(secondsLeft)s")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(secondsLeft <= 10 ? Theme.warning : Theme.textSecondary)
                .contentTransition(.numericText())
            }
        }
        .padding(.top, 2)
        .animation(.easeOut(duration: 0.2), value: revealed)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(store.cards) { c in
                Capsule()
                    .fill(c.id == selectedCardId ? Theme.accent : Theme.strokeSubtle)
                    .frame(width: c.id == selectedCardId ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedCardId)
            }
        }
    }

    // MARK: - Balance

    /// Wallet balance + how much of this card's limit is left.
    ///
    /// The balance shown here is the **wallet's**, not the card's — every card
    /// reaches the same money, so the subtitle says so outright. This is the
    /// screen where a worker with more than one card would otherwise conclude
    /// they have more than one pot of money.
    private var balanceCard: some View {
        let effective = wallet.effectiveLimit(for: card)
        let limitValue = NSDecimalNumber(decimal: effective.amount).doubleValue
        let spent = NSDecimalNumber(decimal: card.spend.amount).doubleValue
        let progress = limitValue > 0 ? min(spent / limitValue, 1.0) : 0

        return VStack(alignment: .leading, spacing: 14) {
            // Everything in this block is the wallet's, not the card's, so it
            // says so once at the top. The card's own name used to sit here as
            // a pill, which made a shared balance look like it belonged to one
            // card — the exact thing "Shared by all your cards" exists to deny.
            HStack(spacing: 6) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("YOUR WALLET")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Available balance")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.5)
                HStack(spacing: 7) {
                    CurrencyIcon(size: 22, color: Theme.textPrimary)
                    Text(formatCurrency(wallet.balanceDecimal))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                }
                Text("Shared by all your cards")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Divider().background(Theme.cardOverlay)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    // Says whose ceiling this is. With no card limit set, the
                    // card spends against the wallet's — which is why the label
                    // switches rather than always saying "Card limit".
                    Text(effective.isWalletLimit
                         ? "Wallet limit · shared"
                         : "This card's limit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        CurrencyIcon(size: 11, color: Theme.textPrimary)
                        Text("\(formatCurrency(card.spend.amount)) of \(formatCurrency(effective.amount)) used")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.cardOverlay)
                        Capsule()
                            .fill(progress >= 0.85 ? Theme.warning : Theme.accent)
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 6)

                // Spend is polled on app open, not streamed — so say when this
                // was true. A worker who reads a stale figure as live gets
                // declined at a till holding a screen that said they had room.
                HStack(spacing: 4) {
                    if let resets = card.spend.resetsOn, effective.period != .never {
                        Text("Resets \(Self.dayFormatter.string(from: resets))")
                        Text("·")
                    }
                    Text("Updated when you opened the app")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f
    }()

    // MARK: - Quick actions

    /// Three tiles, not four.
    ///
    /// **Send is gone.** Sending money is a wallet action — it never touched
    /// this card, and the tile proved it: the handler only switched tabs and
    /// dismissed the screen. Offering it here implied you send *from a card*,
    /// which is the same misunderstanding the "Shared by all your cards" line
    /// above exists to prevent.
    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickActionTile(icon: "plus", title: "Top Up") {
                toast("Top up flow coming soon")
            }
            QuickActionTile(
                icon: card.status == .frozen ? "sun.max.fill" : "snowflake",
                title: card.status == .frozen ? "Unfreeze" : "Freeze",
                tint: card.status == .frozen ? .white : Theme.accent
            ) {
                let wasFrozen = card.status == .frozen
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    store.toggleFreeze(card)
                }
                toast(wasFrozen ? "Card unfrozen" : "Card frozen")
            }
            QuickActionTile(
                icon: revealed ? "eye.slash.fill" : "eye.fill",
                title: revealed ? "Hide" : "Details"
            ) {
                if revealed {
                    withAnimation(.easeOut(duration: 0.2)) { revealed = false }
                } else {
                    BiometricAuth.authenticate(reason: "Authenticate to reveal card details") { success in
                        if success {
                            secondsLeft = Self.revealSeconds
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                revealed = true
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Transactions

    /// Card-scoped activity. Scoping is native on the processor call, so this is
    /// fetched per card rather than filtered out of an account-wide list.
    private var transactionsSection: some View {
        let rows = cardTransactions.transactions(for: card.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !rows.isEmpty {
                    Text("View all")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            if cardTransactions.isLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.accent)
                    Text("Loading your activity…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            } else if rows.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .foregroundStyle(Theme.textSecondary)
                    Text("Nothing on this card yet. Payments show up here as soon as you make them.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, tx in
                        Button {
                            // A decline is its own moment — actionable, not a
                            // receipt. Everything else opens the detail.
                            if tx.declineReason != nil {
                                declinedTransaction = tx
                            } else {
                                pushedTransaction = tx
                            }
                        } label: {
                            CardTxRow(transaction: tx)
                        }
                        .buttonStyle(.plain)

                        if idx < rows.count - 1 {
                            Divider().background(Theme.cardOverlay)
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }
        }
    }

    // MARK: - Delete button

    private var blockButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("Delete card")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showToast = true }
    }

    /// Number only — the dirham glyph is drawn as `CurrencyIcon` beside it so
    /// the currency reads as a symbol rather than the letters "AED".
    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let n = NSDecimalNumber(decimal: value)
        return f.string(from: n) ?? "0.00"
    }
}

// MARK: - Quick action tile

private struct QuickActionTile: View {
    let icon: String
    let title: String
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.cardOverlay)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 46, height: 46)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.card, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tx row
