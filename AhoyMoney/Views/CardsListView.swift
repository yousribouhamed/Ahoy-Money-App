import SwiftUI

/// Full browse screen for all virtual cards.
///
/// We use a horizontally-paged carousel as the hero (Apple Card / Revolut pattern):
/// the focused card is large and tilted; non-focused cards peek from either side.
/// Below the carousel, we show the focused card's metadata (label, status, balance)
/// and a list of "All cards" for at-a-glance browsing.
///
/// Tapping the focused card or any list row pushes `CardDetailView`.
struct CardsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VirtualCardStore.self) private var store

    @State private var focusedIndex: Int = 0
    @State private var showTerms: Bool = false
    @State private var showCreate: Bool = false
    @State private var pushedCardId: UUID? = nil

    private var focusedCard: VirtualCard? {
        guard !store.cards.isEmpty, focusedIndex < store.cards.count else { return nil }
        return store.cards[focusedIndex]
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                topBar

                if store.cards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            carousel.scrollEdgeBlur()
                            focusedSummary.scrollEdgeBlur()
                            allCardsList.scrollEdgeBlur()
                        }
                        .padding(.bottom, 60)
                    }
                    .scrollIndicators(.hidden)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .scrollEdgeEffectStyle(.soft, for: .bottom)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showTerms) {
            CardTermsSheet(onAccepted: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showCreate = true
                }
            })
        }
        .navigationDestination(isPresented: $showCreate) {
            CreateCardView()
        }
        .navigationDestination(item: $pushedCardId) { id in
            CardDetailView(cardId: id)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("My Cards")
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

                Button {
                    showTerms = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 8)
    }

    // MARK: - Carousel

    private var carousel: some View {
        GeometryReader { geo in
            let cardWidth: CGFloat = min(geo.size.width - 80, 320)
            let cardHeight: CGFloat = cardWidth * 0.62

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(Array(store.cards.enumerated()), id: \.element.id) { idx, card in
                        Button {
                            pushedCardId = card.id
                        } label: {
                            CardArtwork(
                                card: card,
                                size: CGSize(width: cardWidth, height: cardHeight)
                            )
                            .scaleEffect(idx == focusedIndex ? 1.0 : 0.93)
                            .opacity(idx == focusedIndex ? 1 : 0.7)
                            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: focusedIndex)
                        }
                        .buttonStyle(.plain)
                        .containerRelativeFrame(.horizontal)
                        .id(idx)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .onScrollGeometryChange(for: Int.self) { proxy in
                let idx = Int((proxy.contentOffset.x / max(proxy.containerSize.width, 1)).rounded())
                return min(max(idx, 0), store.cards.count - 1)
            } action: { _, new in
                if focusedIndex != new {
                    focusedIndex = new
                }
            }
        }
        .frame(height: 230)
        .padding(.top, 12)
        .overlay(alignment: .bottom) {
            if store.cards.count > 1 {
                pageIndicator
                    .padding(.bottom, -10)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<store.cards.count, id: \.self) { i in
                Capsule()
                    .fill(i == focusedIndex ? Theme.accent : Color.white.opacity(0.25))
                    .frame(width: i == focusedIndex ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: focusedIndex)
            }
        }
    }

    // MARK: - Focused summary

    @ViewBuilder
    private var focusedSummary: some View {
        if let card = focusedCard {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.label)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusDot(for: card.status))
                                .frame(width: 6, height: 6)
                            Text(statusLabel(for: card.status))
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(Theme.accent)
                            Text("•")
                                .foregroundStyle(.white.opacity(0.4))
                            Text("•••• \(card.last4)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Balance")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(formatCurrency(card.balance))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }

                HStack(spacing: 10) {
                    smallActionButton(icon: "plus", title: "Top Up") { /* placeholder */ }
                    smallActionButton(
                        icon: card.status == .frozen ? "sun.max.fill" : "snowflake",
                        title: card.status == .frozen ? "Unfreeze" : "Freeze"
                    ) {
                        store.toggleFreeze(card)
                    }
                    smallActionButton(icon: "arrow.up.right", title: "Open") {
                        pushedCardId = card.id
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .padding(.horizontal, 22)
        }
    }

    private func smallActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Theme.accent.opacity(0.12))
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - All cards list

    private var allCardsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All cards")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(store.cards.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
                Spacer()
            }
            .padding(.horizontal, 22)

            VStack(spacing: 0) {
                ForEach(Array(store.cards.enumerated()), id: \.element.id) { idx, card in
                    Button {
                        pushedCardId = card.id
                    } label: {
                        CardListRow(card: card, showDivider: idx < store.cards.count - 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            store.toggleFreeze(card)
                        } label: {
                            Label(
                                card.status == .frozen ? "Unfreeze" : "Freeze",
                                systemImage: card.status == .frozen ? "sun.max" : "snowflake"
                            )
                        }
                        Divider()
                        Button(role: .destructive) {
                            store.remove(card)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 22)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            Text("No cards yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("Issue a virtual card to spend online or add it to Apple Pay — instantly.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showTerms = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Issue your first card")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let n = NSDecimalNumber(decimal: value)
        return "AED \(f.string(from: n) ?? "0.00")"
    }

    private func statusLabel(for status: CardStatus) -> String {
        switch status {
        case .active:  return "ACTIVE"
        case .frozen:  return "FROZEN"
        case .blocked: return "BLOCKED"
        }
    }

    private func statusDot(for status: CardStatus) -> Color {
        switch status {
        case .active:  return Color(red: 0.30, green: 0.85, blue: 0.55)
        case .frozen:  return Color(red: 0.40, green: 0.65, blue: 1.00)
        case .blocked: return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
    }
}

// MARK: - Card list row

private struct CardListRow: View {
    let card: VirtualCard
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Mini card thumbnail.
                CardArtwork(card: card, size: CGSize(width: 60, height: 38))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("•••• \(card.last4)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                        if card.status == .frozen {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(red: 0.40, green: 0.65, blue: 1.00))
                        }
                        if card.status == .blocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())

            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 86)
            }
        }
    }
}

