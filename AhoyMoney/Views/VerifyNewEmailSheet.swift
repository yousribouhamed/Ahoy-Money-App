import SwiftUI

struct VerifyNewEmailSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onVerify: () -> Void = {}

    @State private var code: String = ""
    @FocusState private var focused: Bool

    private let length = 6

    private var canVerify: Bool { code.count == length }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verify your new email")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("A 6-digit verification code has been sent to your email. Enter it below to verify your identity and activate your wallet.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // OTP boxes — overlay a hidden TextField that owns focus & paste support.
            ZStack {
                TextField("", text: Binding(
                    get: { code },
                    set: { newValue in
                        let digits = newValue.filter(\.isNumber).prefix(length)
                        code = String(digits)
                    }
                ))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 8) {
                    ForEach(0..<length, id: \.self) { i in
                        otpBox(index: i)
                    }
                }
            }
            .frame(height: 52)
            .contentShape(.rect)
            .onTapGesture { focused = true }

            Button {
                if canVerify {
                    onVerify()
                    dismiss()
                }
            } label: {
                Text("Verify")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        canVerify ? Theme.accent : Theme.accent.opacity(0.45),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canVerify)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focused = true
            }
        }
    }

    private func otpBox(index: Int) -> some View {
        let chars = Array(code)
        let char: String = index < chars.count ? String(chars[index]) : ""
        let isFocusedHere = focused && index == chars.count

        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.98)) // #FAFAFA
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(white: 0.898), lineWidth: 1) // #E5E5E5
                )

            if char.isEmpty {
                if isFocusedHere {
                    Rectangle()
                        .fill(Theme.grayText)
                        .frame(width: 1.5, height: 22)
                }
            } else {
                Text(char)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
