import SwiftUI

/// Confirmation screen shown after a transfer is successfully scheduled.
///
/// Mirrors the pattern from `BeneficiarySuccessView` / `CardSuccessView`:
/// a hero confirmation, a quick "what happens next" recap, and a primary
/// "Done" button that calls back to the parent (which dismisses the whole
/// schedule flow back to `UpcomingTransfersView`).
struct ScheduleTransferSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BeneficiaryStore.self) private var beneficiaries

    let transfer: UpcomingTransfer
    let onDone: () -> Void

    private var beneficiary: Beneficiary? {
        beneficiaries.items.first(where: { $0.id == transfer.beneficiaryId })
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                hero

                Spacer()

                recap
                    .padding(.horizontal, 22)

                Spacer()

                bottomBar
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .padding(.horizontal, 19)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .headerBlurBackground()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Scheduled")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack {
                Color.clear.frame(width: 44, height: 44)
                Spacer()
                Button {
                    onDone()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Theme.accent.opacity(0.30))
                    .frame(width: 88, height: 88)
                ZStack {
                    Circle().fill(Theme.accent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Theme.accentDeep)
                }
                .frame(width: 64, height: 64)
            }

            VStack(spacing: 6) {
                Text("Schedule confirmed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("\(transfer.currency) \(UpcomingTransfer.format(transfer.amount)) to \(beneficiary?.displayName ?? "your recipient")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
    }

    // MARK: - Recap

    private var recap: some View {
        VStack(spacing: 0) {
            row(
                icon: transfer.frequency.icon,
                label: "Cadence",
                value: transfer.frequency.displayName
            )
            Divider().background(Theme.cardOverlay)
            row(
                icon: "calendar.badge.clock",
                label: "First charge",
                value: transfer.nextRelative,
                accentValue: true
            )
            Divider().background(Theme.cardOverlay)
            row(
                icon: "flag.checkered",
                label: "Ends",
                value: transfer.endRule.displayName
            )
            if let note = transfer.note {
                Divider().background(Theme.cardOverlay)
                row(icon: "text.alignleft", label: "Note", value: note)
            }
        }
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    private func row(icon: String, label: String, value: String, accentValue: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accent.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentValue ? Theme.accent : .white)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.cardOverlay)
            PrimaryWhiteButton(title: "Done") {
                onDone()
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
    }
}
