import SwiftUI

/// Bottom sheet — the entry point for "Add New Beneficiary".
/// Calls `onSelect(kind)` with the chosen rail; the caller dismisses then navigates.
struct BeneficiaryTypeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onSelect: (BeneficiaryKind) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Who are you sending to?")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Choose how you want to send money — we'll guide you through it.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 6) {
                row(
                    emoji: "🌎",
                    title: "International",
                    subtitle: "Send worldwide • SWIFT / IBAN",
                    showDivider: true
                ) {
                    onSelect(.international)
                    dismiss()
                }

                row(
                    emoji: "🇦🇪",
                    title: "UAE Bank Account",
                    subtitle: "Local transfer • arrives same day",
                    showDivider: true
                ) {
                    onSelect(.uae)
                    dismiss()
                }

                row(
                    emoji: "💳",
                    title: "Ahoy Wallet",
                    subtitle: "Instant • free • by phone or Ahoy ID",
                    showDivider: false
                ) {
                    onSelect(.wallet)
                    dismiss()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
    }

    @ViewBuilder
    private func row(emoji: String, title: String, subtitle: String, showDivider: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(red: 0.66, green: 0.93, blue: 1.00)) // #A8EDFF
                        Text(emoji).font(.system(size: 20, weight: .semibold))
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.grayText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.bottom, showDivider ? 8 : 0)

                if showDivider {
                    Rectangle()
                        .fill(Color(red: 0.898, green: 0.898, blue: 0.898))
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
