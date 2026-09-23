import SwiftUI

/// Three-step issuance flow:
///
/// 1. **Design** — pick from 8 designs, see the card update live as a hero preview.
/// 2. **Label** — give the card a name ("Travel", "Subs"). Shown on the chip band.
/// 3. **Review** — confirm details, accept fee disclosure, Face ID, issue.
///
/// On success we push a `CardSuccessView` and clear the navigation stack on dismiss.
struct CreateCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VirtualCardStore.self) private var store

    @State private var step: Int = 0
    @State private var design: CardDesign = .aurora
    @State private var label: String = "Everyday"
    /// True when the flow was opened for the worker rather than by them —
    /// straight off the back of approval. The terms are a legal gate, so they
    /// come first; declining puts them back on the arrival screen.
    var showsTermsFirst: Bool = false
    var onCancelled: () -> Void = {}

    @State private var showTerms: Bool = false
    @State private var issuedCard: VirtualCard? = nil
    @State private var hasShownTerms: Bool = false
    @State private var issuing: Bool = false
    @State private var issueFailed: Bool = false
    @FocusState private var labelFocused: Bool

    private let cardholder = "YOUSRI BOUHAMED"
    private let totalSteps = 3

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                topBar
                ProgressSegments(total: totalSteps, active: step + 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                content

                Spacer(minLength: 0)

                bottomBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard showsTermsFirst, !hasShownTerms else { return }
            hasShownTerms = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showTerms = true }
        }
        .sheet(isPresented: $showTerms) {
            CardTermsSheet(onAccepted: {}, onDeclined: { onCancelled() })
        }
        // Presented over the review step rather than pushed, so a retry keeps
        // the colour and name they already chose instead of starting again.
        .sheet(isPresented: $issueFailed) {
            issueFailedSheet
        }
        .navigationDestination(item: $issuedCard) { card in
            // "Done" unwinds two pushes: the success screen, then this one.
            // Calling `dismiss()` alone did nothing, because it targets this
            // view while the success screen is still pushed on top of it —
            // popping a mid-stack view through an `isPresented` binding is
            // ignored. Clear the child first, then pop self.
            CardSuccessView(card: card) {
                issuedCard = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text(stepTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack {
                Button {
                    if step == 0 { dismiss() }
                    else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step -= 1 }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)

                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 8)
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Pick a design"
        case 1: return "Name your card"
        case 2: return "Review & confirm"
        default: return ""
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Live preview — same on every step.
                let preview = VirtualCard(
                    label: label,
                    design: design,
                    last4: "4421",
                    fullNumber: "4242 4242 4242 4421",
                    expiry: "08/29",
                    cvv: "342",
                    cardholderName: cardholder
                )
                // Width-driven rather than a fixed 320pt, so the preview fills
                // the same margins as everything under it — and matches the
                // size the card will actually be on the wallet screen.
                Color.clear
                    .aspectRatio(340.0 / 212.0, contentMode: .fit)
                    .overlay {
                        GeometryReader { geo in
                            CardArtwork(card: preview, size: geo.size)
                        }
                    }
                    .padding(.top, 12)

                Group {
                    switch step {
                    case 0: designStep
                    case 1: labelStep
                    case 2: reviewStep
                    default: EmptyView()
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .scrollEdgeBlur()
    }

    // MARK: - Step 0: design picker

    @ViewBuilder
    private var designStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your style")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(CardDesign.allCases) { d in
                    DesignSwatch(
                        design: d,
                        isSelected: design == d
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            design = d
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: label

    @ViewBuilder
    private var labelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Give it a memorable name")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Text("Names help you keep track when you have several cards — try “Travel”, “Subscriptions”, or “Online shopping”.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "",
                text: $label,
                prompt: Text("Card name").foregroundStyle(Theme.textSecondary)
            )
            .focused($labelFocused)
            .submitLabel(.done)
            .onSubmit { labelFocused = false }
            .darkFieldStyle()
            .onChange(of: label) { _, newValue in
                // Cap to a sensible visible length on the card band.
                if newValue.count > 24 { label = String(newValue.prefix(24)) }
            }

            // Quick-pick chips.
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggestions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                FlexibleChipRow(
                    options: ["Everyday", "Travel", "Subscriptions", "Shopping", "Bills", "Savings"],
                    selected: label
                ) { picked in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { label = picked }
                }
            }
            .padding(.top, 4)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { labelFocused = true }
        }
    }

    // MARK: - Step 2: review

    @ViewBuilder
    private var reviewStep: some View {
        VStack(spacing: 16) {
            // Summary card.
            VStack(spacing: 0) {
                ReviewLine(label: "Design", value: design.displayName)
                Divider().background(Theme.cardOverlay)
                ReviewLine(label: "Card name", value: label)
                Divider().background(Theme.cardOverlay)
                ReviewLine(label: "Cardholder", value: cardholder.capitalized)
                Divider().background(Theme.cardOverlay)
                ReviewLine(label: "Network", value: "Visa")
                Divider().background(Theme.cardOverlay)
                // Cards are free today but may be priced later, so the value
                // comes from the store rather than being decided here.
                ReviewLine(label: "Cost", value: priceText)
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))

            // The sentence that has to appear on the screen that makes a card.
            // With more than one card in play, "another card means more money"
            // is the misunderstanding that forms here if nothing says otherwise.
            HStack(spacing: 8) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("All your cards spend the same wallet balance. A new card doesn't give you more money — it's another way to reach the money you already have.")
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardOverlay, in: .rect(cornerRadius: 12))

            // Trust footer.
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("You'll authorise issuance with Face ID. The card is ready instantly — no shipping wait.")
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.accent)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.10), in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.cardOverlay)

            HStack {
                PrimaryWhiteButton(title: primaryTitle, enabled: canAdvance) {
                    advance()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
    }

    private var priceText: String {
        switch store.priceOfNextCard {
        case .free:
            return "Free"
        case let .amount(value):
            return "AED \(WalletStore.formatMoney(value))"
        }
    }

    private var primaryTitle: String {
        step == totalSteps - 1 ? "Make card" : "Continue"
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return true
        case 1: return !label.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
        default: return false
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step += 1 }
            return
        }
        // Final step — Face ID, then issue.
        BiometricAuth.authenticate(reason: "Authenticate to issue your virtual card") { success in
            guard success else { return }
            Task {
                issuing = true
                let outcome = await store.issue(
                    label: label,
                    design: design,
                    cardholderName: cardholder
                )
                issuing = false
                switch outcome {
                case let .issued(card):
                    issuedCard = card
                case .failed:
                    // Never terminal — no cooldown and no support route,
                    // because trying again is the whole fix.
                    withAnimation(.easeOut(duration: 0.2)) { issueFailed = true }
                }
            }
        }
    }

    // MARK: - Issue failed

    /// One message, one button.
    ///
    /// No time is promised anywhere in this flow because there is nothing to
    /// wait for — a virtual card is instant when it works. So this doesn't say
    /// "try again later", and it doesn't offer support: the fix is pressing the
    /// button, and the reason belongs in our logs rather than on their screen.
    private var issueFailedSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.86, green: 0.18, blue: 0.24).opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(red: 0.86, green: 0.18, blue: 0.24))
            }
            .padding(.top, 8)

            Text("We couldn't make your card")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text("Nothing was charged and nothing changed. Give it another go.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.grayText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                issueFailed = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { advance() }
            } label: {
                Text("Try again")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.accent, in: .capsule)
            }
            .buttonStyle(.plain)

            Button {
                issueFailed = false
            } label: {
                Text("Not now")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Design swatch

private struct DesignSwatch: View {
    let design: CardDesign
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(design.gradient)
                        .frame(height: 92)
                        // Same facet treatment the real card gets, so the
                        // swatch previews the finished thing rather than a
                        // flat gradient the card never actually looks like.
                        .overlay(
                            FacetPattern(seed: UInt64(abs(design.rawValue.hashValue % 100_000)), cell: 16)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        )
                        .overlay(
                            RadialGradient(
                                colors: [Color.white.opacity(0.25), .clear],
                                center: UnitPoint(x: 0.2, y: 0.0),
                                startRadius: 4, endRadius: 80
                            )
                            .blendMode(.plusLighter)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Theme.accent : Theme.cardOverlay,
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )

                    if isSelected {
                        ZStack {
                            Circle().fill(Theme.accent).frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Theme.accentDeep)
                        }
                        .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(design.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(design.tagline)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review line

private struct ReviewLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

// MARK: - Flexible chip row

private struct FlexibleChipRow: View {
    let options: [String]
    let selected: String
    let action: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let active = selected == option
                    Button {
                        action(option)
                    } label: {
                        Text(option)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(active ? Theme.accentDeep : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(active ? Theme.accent : Theme.cardOverlay)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                active ? Color.clear : Theme.strokeSubtle,
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }
}
