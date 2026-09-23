#if DEBUG
import SwiftUI

/// The card states you can't reach by using the app.
///
/// Issuance failure needs the processor to refuse, the at-limit state needs
/// three cards already made, and every decline arrives as a webhook we have no
/// backend to send. All three are real states with real copy, and without this
/// they can only be read in source.
///
/// Unlike the onboarding debug list, these *do* change the stores — that's the
/// point, since what's being tested is how the app behaves once the state is
/// real. Everything here is reversible from the same screen.
struct CardStatesDebugView: View {
    @Environment(VirtualCardStore.self) private var cards
    @Environment(CardTransactionStore.self) private var transactions

    @State private var lastAction: String?

    private var declines: [(String, DeclineReason)] {
        let walletLimit = Decimal(5_000)
        return [
            ("Not enough money", .insufficientFunds(short: 45)),
            ("Over the limit they set", .overCardLimit(limit: 2_000, walletLimit: walletLimit)),
            ("Over the employer's limit", .overWalletLimit(
                limit: walletLimit,
                resetsOn: Calendar.current.date(byAdding: .month, value: 1, to: Date())
            )),
            ("Card frozen", .cardFrozen),
            // The fallback, with a reason we've never seen and a length nothing
            // was designed around — this is the one that breaks layouts.
            ("Unknown reason (fallback)", .other(
                code: "57",
                message: "Transaction not permitted to cardholder — the issuing processor rejected this merchant category for this card product under scheme rule 57."
            )),
            ("Unknown reason, empty text", .other(code: "96", message: "   "))
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                note

                group("Issuing", subtitle: "The processor can refuse") {
                    toggleRow(
                        "Make issuing fail",
                        detail: "The next card you try to make will fail.",
                        isOn: Binding(
                            get: { (cards.issuer as? MockCardIssuer)?.alwaysFails ?? false },
                            set: { cards.issuer = MockCardIssuer(alwaysFails: $0) }
                        )
                    )
                }

                group("Card slots", subtitle: "\(cards.cards.count) of \(cards.maxCards) used") {
                    actionRow(
                        "Fill every slot",
                        detail: "Makes cards up to the cap, so + shows the at-limit sheet."
                    ) {
                        while cards.canCreateCard {
                            cards.add(VirtualCardStore.makeMockCard(
                                label: "Card \(cards.cards.count + 1)",
                                design: CardDesign.allCases[cards.cards.count % CardDesign.allCases.count],
                                cardholderName: "YOUSRI BOUHAMED"
                            ))
                        }
                        lastAction = "Filled to \(cards.maxCards)"
                    }
                    actionRow("Remove all cards", detail: "Back to the empty state.") {
                        cards.cards = []
                        lastAction = "Cards cleared"
                    }
                }

                group("Declines", subtitle: "Adds a history row and fires the notification") {
                    ForEach(Array(declines.enumerated()), id: \.offset) { _, entry in
                        actionRow(entry.0, detail: entry.1.title) {
                            guard let card = cards.cards.first else {
                                lastAction = "Make a card first"
                                return
                            }
                            transactions.recordDecline(
                                cardId: card.id,
                                merchant: "Carrefour",
                                amount: 142.50,
                                reason: entry.1
                            )
                            lastAction = "Declined: \(entry.0)"
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .background(DarkGradientBackground())
        .navigationTitle("Card states")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let lastAction {
                Text(lastAction)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentDeep)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: .capsule)
                    .padding(.bottom, 30)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: lastAction)
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Debug builds only. These change your cards and history — everything here can be undone from this screen.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardOverlay, in: .rect(cornerRadius: 14))
    }

    private func group<Content: View>(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(spacing: 0) { content() }
                .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }

    private func actionRow(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowBody(title, detail: detail, trailing: nil)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        rowBody(title, detail: detail, trailing: AnyView(
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.accent)
        ))
    }

    private func rowBody(_ title: String, detail: String, trailing: AnyView?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let trailing {
                trailing
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .contentShape(.rect)
    }
}
#endif
