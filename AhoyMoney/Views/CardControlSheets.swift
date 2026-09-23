import SwiftUI

// MARK: - Shared sheet chrome
//
// The app's bottom modals are white with near-black titles and grey body text
// (see CardTermsSheet / VirtualCardSheet). These follow that, rather than the
// dark card surfaces they're launched from.

private extension View {
    /// White bottom-sheet presentation, matching the rest of the app's modals.
    func cardSheetChrome(detents: Set<PresentationDetent>) -> some View {
        self
            .background(Color.white)
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
            .presentationBackground(Color.white)
            // Forces adaptive Theme tokens to resolve light inside the sheet,
            // so a worker in dark mode doesn't get white-on-white fields.
            .environment(\.colorScheme, .light)
    }
}

/// Field styling for the white sheets.
private struct SheetFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.grayBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.grayBorderLight, lineWidth: 1)
                    )
            )
    }
}

private extension View {
    func sheetFieldChrome() -> some View { modifier(SheetFieldChrome()) }
}

// MARK: - Rename

/// Colour and name are ordinary edits a worker can make any time — neither
/// asks for confirmation or authentication.
struct RenameCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentName: String
    let onSave: (String) -> Void

    @State private var name: String = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Card name")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text("Only you see this. It helps you tell your cards apart when you have more than one.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.grayText)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "",
                text: $name,
                prompt: Text("Card name").foregroundStyle(Theme.grayText)
            )
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { if canSave { save() } }
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .sheetFieldChrome()
            .onChange(of: name) { _, new in
                if new.count > 24 { name = String(new.prefix(24)) }
            }

            NameSuggestionChips(selected: trimmed) { picked in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { name = picked }
            }

            Spacer(minLength: 0)

            Button { save() } label: {
                Text("Save")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        canSave ? Theme.accent : Theme.accent.opacity(0.4),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .cardSheetChrome(detents: [.height(390)])
        .onAppear {
            name = currentName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
    }

    private func save() {
        onSave(trimmed)
        dismiss()
    }
}

private struct NameSuggestionChips: View {
    let selected: String
    let action: (String) -> Void

    private let options = ["Everyday", "Travel", "Subscriptions", "Shopping", "Bills", "Savings"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let active = selected == option
                    Button { action(option) } label: {
                        Text(option)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(active ? Theme.accentDeep : Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(active ? Theme.accent : Theme.grayBg)
                                    .overlay(
                                        Capsule().strokeBorder(
                                            active ? Color.clear : Theme.grayBorderLight,
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

// MARK: - Change colour

struct ChangeDesignSheet: View {
    @Environment(\.dismiss) private var dismiss

    let card: VirtualCard
    let onSave: (CardDesign) -> Void

    @State private var picked: CardDesign

    init(card: VirtualCard, onSave: @escaping (CardDesign) -> Void) {
        self.card = card
        self.onSave = onSave
        _picked = State(initialValue: card.design)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Card colour")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Live preview, so the choice is judged on the real card rather
            // than a swatch. Placeholder styling until the brand book lands.
            Color.clear
                .aspectRatio(340.0 / 212.0, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        CardArtwork(card: card, designOverride: picked, size: geo.size)
                    }
                }
                .frame(maxHeight: 170)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(CardDesign.allCases) { design in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                picked = design
                            }
                        } label: {
                            designSwatch(design)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            Button {
                onSave(picked)
                dismiss()
            } label: {
                Text("Save")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        picked != card.design ? Theme.accent : Theme.accent.opacity(0.4),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(picked == card.design)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .cardSheetChrome(detents: [.large])
    }

    private func designSwatch(_ design: CardDesign) -> some View {
        let isSelected = picked == design
        return VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(design.gradient)
                .frame(height: 68)
                .overlay(
                    FacetPattern(
                        seed: UInt64(abs(design.rawValue.hashValue % 100_000)),
                        cell: 14
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.accent : Theme.grayBorderLight,
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        ZStack {
                            Circle().fill(Theme.accent).frame(width: 20, height: 20)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Theme.accentDeep)
                        }
                        .padding(6)
                    }
                }

            Text(design.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.leading, 2)
        }
    }
}

// MARK: - Spending limit

/// The worker's own limit on one card.
///
/// The gauge is capped at the wallet limit their employer set, so the ceiling is
/// something they meet by looking rather than by being refused. There is no
/// route in the app to ask for more, so nothing here reads like a request.
struct CardLimitSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentLimit: CardLimit?
    let walletLimit: Decimal
    let walletPeriod: LimitPeriod
    let onSave: (CardLimit?) -> Void

    @State private var amount: Double
    @State private var period: LimitPeriod

    init(
        currentLimit: CardLimit?,
        walletLimit: Decimal,
        walletPeriod: LimitPeriod,
        onSave: @escaping (CardLimit?) -> Void
    ) {
        self.currentLimit = currentLimit
        self.walletLimit = walletLimit
        self.walletPeriod = walletPeriod
        self.onSave = onSave
        let ceiling = NSDecimalNumber(decimal: walletLimit).doubleValue
        let start = currentLimit.map { NSDecimalNumber(decimal: $0.amount).doubleValue } ?? ceiling
        _amount = State(initialValue: min(start, ceiling))
        _period = State(initialValue: currentLimit?.period ?? walletPeriod)
    }

    private var ceiling: Double { NSDecimalNumber(decimal: walletLimit).doubleValue }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Spending limit")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.ink)

                // States the direction before they run into it.
                Text("Your employer set a limit of AED \(WalletStore.formatMoney(walletLimit)) across your wallet. You can set this card lower, but not higher.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)

                // No forced height: the gauge sizes itself now, and 190 was
                // padding out a card that only needed ~150.
                LimitGaugeCard(
                    title: "This card's limit",
                    value: $amount,
                    minValue: 0,
                    maxValue: ceiling,
                    trackColor: Theme.grayBorderLight,
                    labelColor: Theme.ink
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Resets")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.grayText)

                    Picker("Resets", selection: $period) {
                        ForEach(LimitPeriod.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    onSave(CardLimit(amount: Decimal(amount.rounded()), period: period))
                    dismiss()
                } label: {
                    Text("Save limit")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Button {
                    onSave(nil)
                    dismiss()
                } label: {
                    Text("Remove card limit")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.grayText)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)

                // No "request an increase" anywhere — there is no such route,
                // and offering one would be a dead end.
                Text("Without a card limit, this card can spend up to your wallet limit.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        // Sized to the content. `.large` left a third of the sheet as empty
        // white below the last line, which read as a loading failure rather
        // than as a deliberately short sheet.
        .cardSheetChrome(detents: [.height(600)])
    }
}

// MARK: - Delete

/// Delete confirmation as a bottom sheet.
///
/// The consequences run to three paragraphs — too much for an alert, and a
/// confirmation dialog pushed the buttons off-screen entirely.
struct DeleteCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onDelete: () -> Void

    private let destructive = Color(red: 0.86, green: 0.18, blue: 0.24)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(destructive.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "trash")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(destructive)
            }

            Text("Delete this card for good?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Text("This can't be undone.")
                    .foregroundStyle(Theme.ink)

                Text("Anything set up to pay with this card will stop working — cards you've saved at shops, and anything you pay for every month. You'll need to set those up again with a different card.")
                    .foregroundStyle(Theme.grayText)

                Text("Your money is safe. Your balance is in your wallet, not on the card, so you won't lose anything.")
                    .foregroundStyle(Theme.grayText)
            }
            .font(.system(size: 15, weight: .regular))
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button {
                onDelete()
                dismiss()
            } label: {
                Text("Delete card")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(destructive, in: .capsule)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("Cancel")
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
        .cardSheetChrome(detents: [.height(500)])
    }
}
