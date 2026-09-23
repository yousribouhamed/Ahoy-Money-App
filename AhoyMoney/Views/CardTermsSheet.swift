import SwiftUI

/// Entry point for the virtual card issuance flow.
///
/// Shown as a bottom sheet over the cards list / wallet. Lays out the issuer
/// terms in a scrollable card, requires the user to tick the T&C checkbox,
/// then hands off to `CreateCardView` once they tap Continue.
struct CardTermsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onAccepted: () -> Void = {}
    /// Fired when the sheet closes without agreement — dragged away or backed
    /// out of. Without this, declining the terms silently left the customer on
    /// a card-creation screen they had no right to be on.
    var onDeclined: () -> Void = {}

    @State private var didAccept: Bool = false

    @State private var agreed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator handled by .presentationDragIndicator(.visible)
            VStack(alignment: .leading, spacing: 6) {
                Text("Issue a virtual card")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Spend online with a fresh card number — ready straight away. Review the terms below to continue.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 18)

            // Terms scroll.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    termRow(
                        icon: "creditcard.fill",
                        title: "Issued by Ahoy Bank",
                        // Wallet provisioning is out of scope for R0, so this
                        // no longer promises Apple Pay / Google Pay.
                        body: "Your card is regulated under UAE Central Bank rules and works anywhere online that accepts Visa."
                    )
                    termRow(
                        icon: "shield.lefthalf.filled",
                        title: "Always under your control",
                        // Was: "Block it permanently… we'll route the remaining
                        // balance back to your wallet" — which only makes sense
                        // if the card held money. It doesn't.
                        body: "Freeze the card any time — payments stop, but the card stays valid and the number doesn't change. Delete it and it ends for good."
                    )
                    termRow(
                        icon: "lock.shield.fill",
                        title: "Spending limits",
                        // Was wrong three ways: it used the word "authorised",
                        // hardcoded "monthly", and pointed at Settings. Limits
                        // are per card, and the ceiling is the employer's.
                        body: "Your employer sets a limit across your whole wallet. You can set a lower limit on each card, and change it whenever you like."
                    )
                    termRow(
                        icon: "doc.text.fill",
                        title: "Fees & disclosures",
                        // Doesn't hardcode a price. Cards are free today and
                        // may not be later; the create screen shows the actual
                        // cost from the store before anything is made.
                        body: "Anything a card costs is shown before you make it. An FX margin applies on payments that aren't in AED."
                    )

                    Text("By continuing, you confirm you've read and agree to the **Cardholder Agreement**, **Privacy Notice**, and **Schedule of Fees** issued by Ahoy Bank.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.grayText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)

            // Agreement checkbox + CTA.
            VStack(spacing: 14) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        agreed.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(
                                    agreed ? Theme.accentDeep : Color(white: 0.78),
                                    lineWidth: 1.5
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(agreed ? Theme.accent : Color.clear)
                                )

                            if agreed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(Theme.accentDeep)
                            }
                        }
                        .frame(width: 22, height: 22)

                        Text("I agree to the Terms & Conditions")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    guard agreed else { return }
                    didAccept = true
                    onAccepted()
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            agreed ? Theme.accent : Theme.accent.opacity(0.40),
                            in: .capsule
                        )
                }
                .buttonStyle(.plain)
                .disabled(!agreed)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .onDisappear { if !didAccept { onDeclined() } }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
    }

    // MARK: - Term row

    @ViewBuilder
    private func termRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentDeep)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
