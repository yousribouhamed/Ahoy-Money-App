import SwiftUI

/// The full detail view for a single virtual card.
///
/// Layout:
/// • Top bar — back, "Card", more menu (rename, change design, terminate)
/// • Hero — `CardArtwork` with 3D tilt, status pill underneath
/// • Balance + monthly spend progress
/// • Quick action row — Top Up, Send, Freeze/Unfreeze, Details
/// • Card details card — number/CVV revealed via Face ID toggle
/// • Recent transactions
/// • Block (terminate) button — destructive
///
/// All mutations round-trip through `VirtualCardStore` so the wallet & list
/// stay in sync.
struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VirtualCardStore.self) private var store
    @Environment(AppRouter.self) private var router

    let cardId: UUID

    @State private var revealed: Bool = false
    @State private var showBlockConfirm: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    /// Latest copy from the store so freeze / rename / etc. reflect live.
    private var card: VirtualCard {
        store.cards.first(where: { $0.id == cardId })
            ?? store.cards.first!  // Always at least one demo card seeded.
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 22) {
                    hero.scrollEdgeBlur()
                    balanceCard.scrollEdgeBlur()
                    quickActions.scrollEdgeBlur()
                    detailsCard.scrollEdgeBlur()
                    transactionsSection.scrollEdgeBlur()
                    blockButton.scrollEdgeBlur()
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .padding(.horizontal, 19)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Block this card?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block & remove", role: .destructive) {
                store.setStatus(card, .blocked)
                toast("Card blocked")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    store.remove(card)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Blocking is permanent. The card number can't be reactivated. Any remaining balance returns to your wallet.")
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
                .foregroundStyle(.white)

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
                        // Rename — placeholder hook (could push an edit sheet).
                        toast("Rename coming soon")
                    } label: {
                        Label("Rename card", systemImage: "pencil")
                    }
                    Button {
                        toast("Change design coming soon")
                    } label: {
                        Label("Change design", systemImage: "paintpalette")
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
                        showBlockConfirm = true
                    } label: {
                        Label("Block & terminate", systemImage: "lock.fill")
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

    private var hero: some View {
        VStack(spacing: 12) {
            CardArtwork(
                card: card,
                size: CGSize(width: 340, height: 212),
                revealed: revealed,
                tiltEnabled: true
            )
            .padding(.top, 6)

            // Status pill.
            StatusPill(status: card.status)
        }
    }

    // MARK: - Balance

    private var balanceCard: some View {
        let limit = NSDecimalNumber(decimal: card.monthlyLimit).doubleValue
        let spent = NSDecimalNumber(decimal: card.spentThisMonth).doubleValue
        let progress = limit > 0 ? min(spent / limit, 1.0) : 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available balance")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(0.5)
                    Text(formatCurrency(card.balance))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                Spacer()
                Text(card.label)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Spent this month")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(formatCurrency(card.spentThisMonth)) / \(formatCurrency(card.monthlyLimit))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(progress >= 0.85 ? Theme.warning : Theme.accent)
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickActionTile(icon: "plus", title: "Top Up") {
                toast("Top up flow coming soon")
            }
            QuickActionTile(icon: "paperplane.fill", title: "Send") {
                router.selectedTab = .send
                dismiss()
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
                    revealed = false
                } else {
                    BiometricAuth.authenticate(reason: "Authenticate to reveal card details") { success in
                        if success {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                revealed = true
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Card details (number, expiry, cvv)

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CARD DETAILS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if revealed {
                    Button {
                        UIPasteboard.general.string = card.fullNumber.filter(\.isNumber)
                        toast("Card number copied")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                detailRow(
                    label: "Card number",
                    value: revealed ? card.formattedNumber : "•••• •••• •••• \(card.last4)",
                    monospaced: true
                )
                Divider().background(Color.white.opacity(0.08))
                    .padding(.leading, 14)

                HStack(spacing: 0) {
                    detailRow(
                        label: "Expires",
                        value: card.expiry,
                        monospaced: true,
                        compact: true
                    )
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1, height: 28)

                    detailRow(
                        label: "CVV",
                        value: revealed ? card.cvv : "•••",
                        monospaced: true,
                        compact: true
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, monospaced: Bool = false, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.4)
            Text(value)
                .font(.system(size: compact ? 14 : 16, weight: .semibold, design: monospaced ? .monospaced : .default))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Transactions placeholder

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("View all")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            if mockTransactions.isEmpty {
                HStack {
                    Image(systemName: "tray")
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No transactions yet — start spending with this card.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mockTransactions.enumerated()), id: \.offset) { idx, t in
                        TxRow(merchant: t.0, subtitle: t.1, amount: t.2)
                        if idx < mockTransactions.count - 1 {
                            Divider().background(Color.white.opacity(0.06))
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }
        }
    }

    // Demo content — newly issued cards have nothing.
    private var mockTransactions: [(String, String, String)] {
        guard card.spentThisMonth > 0 else { return [] }
        return [
            ("Netflix", "Subscription • Today", "-AED 39.00"),
            ("Carrefour", "Groceries • Yesterday", "-AED 142.50"),
            ("Apple", "App Store • 2 days ago", "-AED 8.00")
        ]
    }

    // MARK: - Block button

    private var blockButton: some View {
        Button {
            showBlockConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Block & terminate card")
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

    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let n = NSDecimalNumber(decimal: value)
        return "AED \(f.string(from: n) ?? "0.00")"
    }
}

// MARK: - Status pill

private struct StatusPill: View {
    let status: CardStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: .capsule)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var label: String {
        switch status {
        case .active:  return "ACTIVE"
        case .frozen:  return "FROZEN"
        case .blocked: return "BLOCKED"
        }
    }

    private var dot: Color {
        switch status {
        case .active:  return Color(red: 0.30, green: 0.85, blue: 0.55)
        case .frozen:  return Color(red: 0.40, green: 0.65, blue: 1.00)
        case .blocked: return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
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
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 46, height: 46)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.card, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tx row

private struct TxRow: View {
    let merchant: String
    let subtitle: String
    let amount: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08))
                Image(systemName: "bag.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(merchant)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            Text(amount)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
