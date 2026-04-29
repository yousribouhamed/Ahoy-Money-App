import SwiftUI

struct TopUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WalletStore.self) private var wallet

    @State private var selectedAmount: Int? = nil
    @State private var customAmount: String = ""
    @State private var paymentMethod: PaymentMethod = .card
    @State private var showPaymentSheet: Bool = false
    @State private var showCustomAmount: Bool = false

    private var paymentMethodLabel: String {
        switch paymentMethod {
        case .card:         return "Card ending **91"
        case .applePay:     return "Apple Pay"
        case .bankTransfer: return "Bank Transfer"
        }
    }

    private var paymentMethodSymbol: String {
        switch paymentMethod {
        case .card:         return "creditcard.fill"
        case .applePay:     return "applelogo"
        case .bankTransfer: return "building.columns.fill"
        }
    }

    private let amounts: [Int] = [50, 100, 250, 500, 1000, 2500]

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Top Up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack {
                        Button {
                            dismiss()
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

                VStack(spacing: 24) {
                    // Wallet Balance card (matches Home screen, full width).
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wallet Balance")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                        HStack(spacing: 6) {
                            CurrencyIcon(size: 16)
                            Text(WalletStore.formatMoney(wallet.balance))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    // Custom Amount field.
                    Button {
                        showCustomAmount = true
                    } label: {
                        HStack(spacing: 6) {
                            if customAmount.isEmpty {
                                Text("Custom Amount")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.subText)
                            } else {
                                CurrencyIcon(size: 16, color: .white)
                                Text(customAmount)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.card, in: .rect(cornerRadius: 16))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Load Amounts grid.
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Load Amounts")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.accent)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                ForEach(amounts.prefix(3), id: \.self) { amount in
                                    AmountChip(value: amount, selected: selectedAmount == amount) {
                                        selectedAmount = amount
                                        customAmount = ""
                                    }
                                }
                            }
                            HStack(spacing: 12) {
                                ForEach(amounts.suffix(3), id: \.self) { amount in
                                    AmountChip(value: amount, selected: selectedAmount == amount) {
                                        selectedAmount = amount
                                        customAmount = ""
                                    }
                                }
                            }
                        }
                    }

                    // Payment Method.
                    Button {
                        showPaymentSheet = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Payment Method")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.accent)

                                HStack(spacing: 8) {
                                    Image(systemName: paymentMethodSymbol)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .frame(width: 32, height: 32)
                                        .background(Color.white, in: .rect(cornerRadius: 8))

                                    Text(paymentMethodLabel)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Top Up Wallet button.
                    Button {
                        BiometricAuth.authenticate(reason: "Authenticate to top up your wallet") { success in
                            guard success else { return }
                            if let amount = effectiveAmount {
                                wallet.balance += Double(amount)
                            }
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isValid {
                                CurrencyIcon(size: 15, color: .black)
                            }
                            Text(isValid ? buttonAmountText : "Top Up Wallet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(isValid ? Color.white : Theme.disabled, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                Spacer()
            }
        }
        .sheet(isPresented: $showPaymentSheet) {
            PaymentMethodSheet(selected: $paymentMethod)
        }
        .sheet(isPresented: $showCustomAmount) {
            CustomAmountSheet(amount: $customAmount)
                .onDisappear {
                    if !customAmount.isEmpty { selectedAmount = nil }
                }
        }
    }

    private var buttonAmountText: String {
        guard let amount = effectiveAmount else { return "Top Up Wallet" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return "Top Up " + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }

    private var buttonTitle: String {
        guard let amount = effectiveAmount else { return "Top Up Wallet" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        let formatted = f.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "Top Up \(formatted)"
    }

    private var effectiveAmount: Int? {
        if let s = selectedAmount { return s }
        return Int(customAmount)
    }

    private var isValid: Bool {
        if let a = effectiveAmount { return a > 0 }
        return false
    }
}

private struct AmountChip: View {
    let value: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CurrencyIcon(size: 16, color: selected ? Color(red: 0.012, green: 0.055, blue: 0.161) : .white)
                Text("\(value)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(selected ? Color(red: 0.012, green: 0.055, blue: 0.161) : .white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 65)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected ? Theme.accent : Color.white.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}
