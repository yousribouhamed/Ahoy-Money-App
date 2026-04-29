import SwiftUI

enum PaymentMethod: String, CaseIterable, Identifiable {
    case card, applePay, bankTransfer
    var id: String { rawValue }

    var title: String {
        switch self {
        case .card:         return "Credit/Debit Card"
        case .applePay:     return "Apple Pay"
        case .bankTransfer: return "Bank Transfer"
        }
    }
}

struct PaymentMethodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: PaymentMethod

    @State private var draft: PaymentMethod

    init(selected: Binding<PaymentMethod>) {
        self._selected = selected
        self._draft = State(initialValue: selected.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Title.
            Text("Select Payment Method")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Options.
            VStack(spacing: 16) {
                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        draft = method
                    } label: {
                        HStack(spacing: 8) {
                            RadioDot(selected: draft == method)

                            HStack(spacing: 8) {
                                MethodIcon(method: method)
                                Text(method.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.black)
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Add button.
            Button {
                selected = draft
                dismiss()
            } label: {
                Text("Add")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.black, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.white)
    }
}

private struct RadioDot: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(selected ? Color(red: 0.02, green: 0.004, blue: 0.23) : Color(red: 0.925, green: 0.937, blue: 0.949))
                .overlay(
                    Circle().strokeBorder(
                        selected ? Theme.accent : Color(red: 0.4, green: 0.502, blue: 0.569),
                        lineWidth: 1
                    )
                )
            if selected {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct MethodIcon: View {
    let method: PaymentMethod

    var body: some View {
        Group {
            switch method {
            case .card:
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 32)
                    .background(Color(red: 0.898, green: 0.898, blue: 0.898), in: .rect(cornerRadius: 8))
            case .applePay:
                HStack(spacing: 2) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("Pay")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .frame(width: 40, height: 32)
            case .bankTransfer:
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 32)
                    .background(Color(red: 0.898, green: 0.898, blue: 0.898), in: .rect(cornerRadius: 8))
            }
        }
    }
}
