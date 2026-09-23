import SwiftUI

// MARK: - Status pill

/// The shared vocabulary, rendered. Same words here as on the account-level
/// Transactions page — they come from one type so they can't drift.
struct TransactionStatusPill: View {
    let status: TransactionStatus
    var compact: Bool = false

    var body: some View {
        Text(status.displayName)
            .font(.system(size: compact ? 10 : 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 3)
            .background(tint.opacity(0.15), in: .capsule)
    }

    private var tint: Color {
        switch status {
        case .onHold: return Theme.warning
        case .paid:   return Color(red: 0.34, green: 0.85, blue: 0.55)
        case .failed: return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
    }
}

// MARK: - Row

struct CardTxRow: View {
    let transaction: CardTransaction

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.cardOverlay)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    TransactionStatusPill(status: transaction.status, compact: true)
                    Text(Self.dateFormatter.string(from: transaction.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("−")
                    CurrencyIcon(size: 11, color: amountColor)
                    Text(WalletStore.formatMoney(transaction.amount))
                }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(amountColor)
                .strikethrough(isDeclined, color: amountColor)

                if transaction.isInternational, let fx = transaction.fx {
                    Text("\(fx.currencyCode) \(WalletStore.formatMoney(fx.originalAmount))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var isDeclined: Bool { transaction.declineReason != nil }

    private var amountColor: Color {
        isDeclined ? Theme.textSecondary : Theme.textPrimary
    }

    private var icon: String {
        if isDeclined { return "exclamationmark.circle" }
        return transaction.isInternational ? "globe" : "bag.fill"
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()
}

// MARK: - Detail

/// One payment, in full.
///
/// This is where the held-vs-settled difference is taught — once, in a sentence,
/// and without the word "authorised".
struct CardTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let transaction: CardTransaction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(transaction.merchant)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)

                    HStack(spacing: 6) {
                        CurrencyIcon(size: 20, color: Theme.ink)
                        Text(WalletStore.formatMoney(transaction.amount))
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                    }

                    TransactionStatusPill(status: transaction.status)
                }

                // Taught once, here — not repeated on every row.
                if case .onHold = transaction.status {
                    infoBox(TransactionStatus.holdExplainer)
                }

                // A decline answers one question: can this be fixed now.
                if let reason = transaction.declineReason {
                    declineBox(reason)
                }

                VStack(spacing: 0) {
                    detailRow("Date", Self.longFormatter.string(from: transaction.date))
                    divider
                    detailRow("Status", transaction.status.displayName)

                    if let fx = transaction.fx {
                        divider
                        detailRow("Paid in", "\(fx.currencyCode) \(WalletStore.formatMoney(fx.originalAmount))")
                        if let rate = fx.rate {
                            divider
                            detailRow("Exchange rate", "1 \(fx.currencyCode) = \(WalletStore.formatMoney(rate)) AED")
                        }
                        divider
                        detailRow("Charged", "AED \(WalletStore.formatMoney(transaction.amount))")
                    }
                }
                .background(Theme.grayBg, in: .rect(cornerRadius: 14))

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.grayBorderLight)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.grayText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func infoBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    private func declineBox(_ reason: DeclineReason) -> some View {
        let red = Color(red: 0.86, green: 0.18, blue: 0.24)
        return VStack(alignment: .leading, spacing: 6) {
            Text(reason.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(red)
            Text(reason.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.grayText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(red.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy, HH:mm"
        return f
    }()
}

// MARK: - Decline

/// What a worker sees when a payment is refused.
///
/// Read at a till with someone waiting behind them, so it answers one question
/// — can this be fixed right now — and offers at most one thing to press.
///
/// Four reasons carry written copy. Everything else arrives as `.other` and
/// renders whatever the processor sent, which is why nothing here assumes a
/// length: the text scrolls and the sheet grows rather than clipping a message
/// we've never seen.
struct DeclineSheet: View {
    @Environment(\.dismiss) private var dismiss

    let reason: DeclineReason
    var merchant: String? = nil
    var amount: Decimal? = nil
    var onAction: (DeclineReason.ActionKind) -> Void = { _ in }

    private let red = Color(red: 0.86, green: 0.18, blue: 0.24)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(red.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "creditcard.trianglebadge.exclamationmark")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(red)
                }

                // The first line carries the whole message on its own.
                Text(reason.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let merchant, let amount {
                    HStack(spacing: 6) {
                        Text(merchant)
                        Text("·")
                        CurrencyIcon(size: 12, color: Theme.grayText)
                        Text(WalletStore.formatMoney(amount))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.grayText)
                }

                Text(reason.message)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)

                // A reason we've never seen gets a quieter note, so a worker
                // knows the wording came from their bank rather than from us.
                if case .other = reason {
                    Text("This came from your bank.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.grayText.opacity(0.8))
                }

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    if let action = reason.action {
                        Button {
                            onAction(action.kind)
                            dismiss()
                        } label: {
                            Text(action.label)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(Theme.accent, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(reason.action == nil ? "Close" : "Not now")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .environment(\.colorScheme, .light)
    }
}
