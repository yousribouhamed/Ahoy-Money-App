import SwiftUI

/// Final security gate before a beneficiary is saved.
/// Mirrors the email/phone OTP sheets — same chrome, same height, same UX —
/// so users learn the pattern once and reuse it everywhere.
struct BeneficiaryOtpSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Plain-English label for the kind of beneficiary being added —
    /// shown in the headline so the user knows exactly what they're authorising.
    var kindLabel: String = "beneficiary"
    var onVerify: () -> Void = {}

    @State private var code: String = ""
    @State private var resendCooldown: Int = 30
    @State private var resendTimer: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    private let length = 6
    private var canVerify: Bool { code.count == length }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Confirm new \(kindLabel) beneficiary")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("We sent a 6-digit code to your registered phone. Enter it below to finish adding this contact.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // OTP boxes (hidden TextField behind for keyboard input).
            ZStack {
                TextField("", text: Binding(
                    get: { code },
                    set: { newValue in
                        code = String(newValue.filter(\.isNumber).prefix(length))
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

            // Resend row.
            HStack(spacing: 4) {
                Text("Didn't get a code?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.grayText)

                Button {
                    if resendCooldown == 0 { startResendTimer() }
                } label: {
                    Text(resendCooldown == 0 ? "Resend" : "Resend in \(resendCooldown)s")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(resendCooldown == 0 ? Theme.accent : Theme.grayText)
                }
                .buttonStyle(.plain)
                .disabled(resendCooldown != 0)

                Spacer()
            }

            Button {
                if canVerify {
                    onVerify()
                    dismiss()
                }
            } label: {
                Text("Verify & Add")
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
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true }
            startResendTimer()
        }
        .onDisappear { resendTimer?.cancel() }
    }

    private func startResendTimer() {
        resendCooldown = 30
        resendTimer?.cancel()
        resendTimer = Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run { resendCooldown -= 1 }
            }
        }
    }

    private func otpBox(index: Int) -> some View {
        let chars = Array(code)
        let char: String = index < chars.count ? String(chars[index]) : ""
        let isFocusedHere = focused && index == chars.count

        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isFocusedHere ? Theme.accent : Color(white: 0.898),
                            lineWidth: isFocusedHere ? 1.5 : 1
                        )
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
