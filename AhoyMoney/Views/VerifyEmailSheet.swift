import SwiftUI

struct VerifyEmailSheet: View {
    @Environment(\.dismiss) private var dismiss

    var subtitle: String = "A 6-digit verification code has been sent to your email. Enter it below to verify your identity and activate your wallet."
    var onVerify: () -> Void = {}

    @State private var code: String = ""
    @FocusState private var focused: Bool

    private let length = 6

    private var canVerify: Bool { code.count == length }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Verify Email")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)

                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // OTP boxes — overlay a hidden TextField that owns the focus & paste support.
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
                .opacity(0.001) // invisible but interactive
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 12) {
                    ForEach(0..<length, id: \.self) { i in
                        otpBox(index: i)
                    }
                }
            }
            .frame(height: 56)
            .contentShape(.rect)
            .onTapGesture { focused = true }
            .padding(.top, 4)

            Button {
                if canVerify {
                    onVerify()
                    dismiss()
                }
            } label: {
                Text("Verify")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        canVerify
                            ? Color(red: 0, green: 0xCD/255, blue: 1)
                            : Color(red: 0, green: 0xCD/255, blue: 1).opacity(0.45),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canVerify)

        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color.white)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(white: 0.85), lineWidth: 1)
                )

            if char.isEmpty {
                if isFocusedHere {
                    BlinkingCaret()
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

private struct BlinkingCaret: View {
    @State private var on = true
    var body: some View {
        Rectangle()
            .fill(Color.black)
            .frame(width: 1.5, height: 22)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    on.toggle()
                }
            }
    }
}
