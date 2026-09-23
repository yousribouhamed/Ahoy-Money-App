import SwiftUI

/// The normal outcome, and the one designed first.
///
/// **An arrival, not a result.** A clean file opens the wallet with no person
/// involved and no waiting — so this isn't a verdict screen. There's no
/// checkmark and no "approved".
///
/// **No card here.** A card is never issued automatically; the customer makes
/// one, and until they do there is nothing to show. Putting artwork for a card
/// that doesn't exist on the arrival screen promised something the app hadn't
/// done — worse, it made the one action we most want them to take look like it
/// had already happened.
///
/// So the screen becomes a short list of what they can do next, borrowing
/// Wise's split between things worth doing and things that are genuinely
/// optional. The distinction is carried visually: the card row is solid, the
/// two optional rows are dashed. A dashed border reads as an empty slot, which
/// is exactly what they are — and it's what keeps email and proof of address
/// from looking like conditions on an account that is already open.
struct WalletCreatedView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(VirtualCardStore.self) private var cards

    var onContinue: () -> Void = {}
    /// Enter the app and go straight into making a card.
    var onCreateCard: () -> Void = {}

    @State private var arrived = false
    @State private var showEmailSheet = false
    @State private var importingAddress = false

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        walletMark
                            .padding(.top, 36)

                        VStack(spacing: 10) {
                            Text("Your wallet is open")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(cards.cards.isEmpty
                                 ? "Add money whenever you like. When you're ready to spend, make yourself a card."
                                 : "Add money whenever you like, and spend it with the card you just made.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 30)
                        }
                        .padding(.top, 22)


                        createCardRow
                            .padding(.top, 10)

                        sectionLabel("OPTIONAL")
                            .padding(.top, 26)

                        VStack(spacing: 10) {
                            optionalRow(.email)
                            optionalRow(.proofOfAddress)
                        }
                        .padding(.top, 10)

                        Text("Neither is required, here or later. They're in Settings whenever you want them.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    .opacity(arrived ? 1 : 0)
                    .offset(y: arrived ? 0 : 12)
                }
                .scrollIndicators(.hidden)

                PrimaryWhiteButton(title: "Start using Ahoy", enabled: true) {
                    onContinue()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(0.1)) {
                arrived = true
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            VerifyEmailSheet(onVerify: { onboarding.complete(.email) })
        }
        .fileImporter(
            isPresented: $importingAddress,
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success = result { onboarding.complete(.proofOfAddress) }
        }
    }

    private var walletMark: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.10))
                .frame(width: 118, height: 118)
            Circle()
                .fill(Theme.accent.opacity(0.18))
                .frame(width: 86, height: 86)
            CurrencyIcon(size: 38, color: Theme.accent)
        }
        .scaleEffect(arrived ? 1 : 0.6)
        .opacity(arrived ? 1 : 0)
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Rows

    /// Solid, and the only row with an accent icon. This is the thing they came
    /// for, but it's still a choice rather than a step — the wallet works
    /// without it.
    private var createCardRow: some View {
        // Once they've made one, this stops asking. Coming back from the card
        // flow to a screen still saying "Create your card" would read as though
        // it hadn't worked.
        let hasCard = !cards.cards.isEmpty

        return Button(action: { if !hasCard { onCreateCard() } }) {
            rowContent(
                icon: "creditcard.fill",
                iconTint: Theme.accentDeep,
                iconBackground: Theme.accent,
                title: hasCard ? "Your card is ready" : "Create your card",
                detail: hasCard
                    ? "It spends from your wallet balance."
                    : "A virtual card you can use as soon as it's made.",
                trailing: hasCard ? .done : .chevron
            )
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.cardOverlay)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(hasCard)
    }

    /// Dashed, muted icon, and a "Done" state instead of a chevron once it's
    /// been dealt with. Nothing here ever turns into a warning.
    private func optionalRow(_ item: ChecklistItem) -> some View {
        let done = !onboarding.outstandingItems.contains(item)

        return Button {
            guard !done else { return }
            switch item {
            case .email:          showEmailSheet = true
            case .proofOfAddress: importingAddress = true
            }
        } label: {
            rowContent(
                icon: item.icon,
                iconTint: done ? Theme.accentDeep : Theme.textSecondary,
                iconBackground: done ? Theme.accent : Color.white.opacity(0.06),
                title: item.title,
                detail: item.detail,
                trailing: done ? .done : .chevron
            )
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(done ? Theme.cardOverlay : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                Theme.strokeSubtle,
                                style: StrokeStyle(
                                    lineWidth: 1,
                                    // Dashed while it's an empty slot; solid
                                    // once there's something in it.
                                    dash: done ? [] : [5, 4]
                                )
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(done)
    }

    private enum Trailing { case chevron, done }

    private func rowContent(
        icon: String,
        iconTint: Color,
        iconBackground: Color,
        title: String,
        detail: String,
        trailing: Trailing = .chevron
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 40, height: 40)
                .background(iconBackground, in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            switch trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            case .done:
                Text("Done")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .contentShape(.rect)
    }
}

// MARK: - Previews

#Preview("Arrival — nothing done yet") {
    let store = OnboardingStore()
    store.approveInstantly()
    return WalletCreatedView()
        .environment(store)
        .environment(WalletStore())
        .environment(VirtualCardStore())
}

#Preview("Arrival — optional items done") {
    let store = OnboardingStore()
    store.approveInstantly()
    store.complete(.email)
    store.complete(.proofOfAddress)
    return WalletCreatedView()
        .environment(store)
        .environment(WalletStore())
        .environment(VirtualCardStore())
}
