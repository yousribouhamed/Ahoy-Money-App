import SwiftUI

/// Entry point for the virtual card issuance flow.
///
/// Shown as a bottom sheet over the cards list / wallet. Lays out the issuer
/// terms in a scrollable card, requires the user to tick the T&C checkbox,
/// then hands off to `CreateCardView` once they tap Continue.
struct CardTermsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onAccepted: () -> Void = {}

    @State private var agreed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator handled by .presentationDragIndicator(.visible)
            VStack(alignment: .leading, spacing: 6) {
                Text("Issue a virtual card")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Spend online or in-store with a fresh card number — instantly. Review the terms below to continue.")
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
                        body: "Your card is regulated under UAE Central Bank rules. It can be used wherever Visa is accepted online and via Apple Pay / Google Pay."
                    )
                    termRow(
                        icon: "shield.lefthalf.filled",
                        title: "Always under your control",
                        body: "Freeze the card in one tap. Block it permanently if you suspect fraud — we'll route the remaining balance back to your wallet."
                    )
                    termRow(
                        icon: "lock.shield.fill",
                        title: "Limits & verification",
                        body: "Each transaction is authorised with Face ID or 3-D Secure. You can adjust monthly limits anytime in Settings."
                    )
                    termRow(
                        icon: "doc.text.fill",
                        title: "Fees & disclosures",
                        body: "Free issuance for the first card. AED 5 fee per additional card. FX margin applies on non-AED purchases."
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
