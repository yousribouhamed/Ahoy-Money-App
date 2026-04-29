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
    @State private var issuedCard: VirtualCard? = nil
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
        .navigationDestination(item: $issuedCard) { card in
            CardSuccessView(card: card) {
                dismiss()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text(stepTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

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
                    balance: 0,
                    last4: "4421",
                    fullNumber: "4242 4242 4242 4421",
                    expiry: "08/29",
                    cvv: "342",
                    cardholderName: cardholder
                )
                CardArtwork(card: preview, size: CGSize(width: 320, height: 200))
                    .padding(.top, 12)
                    .scrollEdgeBlur()

                Group {
                    switch step {
                    case 0: designStep
                    case 1: labelStep
                    case 2: reviewStep
                    default: EmptyView()
                    }
                }
                .scrollEdgeBlur()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Step 0: design picker

    @ViewBuilder
    private var designStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your style")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

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
                .foregroundStyle(.white)

            Text("Names help you keep track when you have several cards — try “Travel”, “Subscriptions”, or “Online shopping”.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "",
                text: $label,
                prompt: Text("Card name").foregroundStyle(.white.opacity(0.45))
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
                    .foregroundStyle(.white.opacity(0.6))

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
                Divider().background(Color.white.opacity(0.08))
                ReviewLine(label: "Card name", value: label)
                Divider().background(Color.white.opacity(0.08))
                ReviewLine(label: "Cardholder", value: cardholder.capitalized)
                Divider().background(Color.white.opacity(0.08))
                ReviewLine(label: "Network", value: "Visa")
                Divider().background(Color.white.opacity(0.08))
                ReviewLine(
                    label: "Issuance fee",
                    value: store.cards.isEmpty ? "Free (first card)" : "AED 5"
                )
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))

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
            Divider().background(Color.white.opacity(0.06))

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

    private var primaryTitle: String {
        step == totalSteps - 1 ? "Issue card with Face ID" : "Continue"
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
        // Final step — Face ID, then create.
        BiometricAuth.authenticate(reason: "Authenticate to issue your virtual card") { success in
            guard success else { return }
            let new = VirtualCardStore.makeMockCard(
                label: label,
                design: design,
                cardholderName: cardholder
            )
            store.add(new)
            issuedCard = new
        }
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
                                    isSelected ? Theme.accent : Color.white.opacity(0.08),
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
                        .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
                                    .fill(active ? Theme.accent : Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                active ? Color.clear : Color.white.opacity(0.15),
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
