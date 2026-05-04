import SwiftUI

struct CustomAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var amount: String

    @State private var draft: String
    @FocusState private var focused: Bool

    init(amount: Binding<String>) {
        self._amount = amount
        self._draft = State(initialValue: amount.wrappedValue)
    }

    private var displayValue: String {
        let cleaned = draft.filter(\.isNumber)
        if cleaned.isEmpty { return "0.00" }
        if let v = Double(cleaned) {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            return f.string(from: NSNumber(value: v)) ?? "0.00"
        }
        return "0.00"
    }

    private var isValid: Bool {
        if let v = Double(draft.filter(\.isNumber)), v >= 1 { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 24) {
            // Amount display.
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image("currency_baht")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 38)
                        .foregroundStyle(.black)
                    RollingAmountText(value: displayValue)
                }
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.black)
                        .frame(height: 1)
                }

                Text("1.00 Minimum")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.898, green: 0.91, blue: 0.925), in: .capsule)
            }
            .padding(.top, 24)

            // Hidden text field to trigger the numeric keyboard.
            TextField("", text: $draft)
                .keyboardType(.numberPad)
                .focused($focused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: draft) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue { draft = filtered }
                }

            // Add button.
            Button {
                if isValid {
                    amount = draft.filter(\.isNumber)
                    dismiss()
                }
            } label: {
                Text("Add")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(isValid ? Color.black : Color.black.opacity(0.4), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(!isValid)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focused = true
            }
        }
    }
}

private struct RollingAmountText: View {
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(value.enumerated()), id: \.offset) { _, character in
                RollingAmountCharacter(character: character)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
            }
        }
        .font(.system(size: 48, weight: .bold, design: .default))
        .monospacedDigit()
        .foregroundStyle(.black)
        .animation(.smooth(duration: 0.22), value: value)
        .accessibilityLabel(value)
    }
}

private struct RollingAmountCharacter: View {
    let character: Character

    private var width: CGFloat {
        switch character {
        case ".", ",":
            return 14
        default:
            return 31
        }
    }

    var body: some View {
        ZStack {
            Text(String(character))
                .id(character)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
        }
        .frame(width: width, height: 58)
        .clipped()
    }
}
