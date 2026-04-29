import SwiftUI

/// Full-screen celebration after a beneficiary is saved.
/// Two clear next steps — "Send money now" pushes the user into the active
/// transfer flow with this contact pre-selected, while "Done" simply returns
/// them to the Send tab where the new contact is already pinned to Suggested.
struct BeneficiarySuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    let beneficiary: Beneficiary

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                // Animated tick.
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 160, height: 160)
                    Circle()
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.accentDeep)
                }
                .padding(.bottom, 24)

                Text("Beneficiary added")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(beneficiary.nickname ?? beneficiary.name) is ready to receive money.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 6)

                // Compact summary card — shows the user what they just saved.
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(beneficiary.avatarBg)
                        Text(beneficiary.initial)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(beneficiary.nickname ?? beneficiary.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            if beneficiary.kind == .wallet {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        Text(beneficiary.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }

                    Spacer()

                    KindBadge(kind: beneficiary.kind)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer()

                VStack(spacing: 12) {
                    PrimaryWhiteButton(title: "Send money now") {
                        // Go back to the Send tab — the new contact is at the top of Suggested.
                        router.selectedTab = .send
                        // Dismiss the entire flow.
                        dismiss()
                    }

                    Button {
                        router.selectedTab = .send
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct KindBadge: View {
    let kind: BeneficiaryKind
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.accent.opacity(0.15), in: .capsule)
    }

    private var label: String {
        switch kind {
        case .wallet:        return "WALLET"
        case .uae:           return "UAE BANK"
        case .international: return "INTERNATIONAL"
        }
    }
}
