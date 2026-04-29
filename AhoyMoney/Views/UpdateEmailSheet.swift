import SwiftUI

struct UpdateEmailSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onSendCode: (String) -> Void = { _ in }

    @State private var email: String = ""
    @FocusState private var focused: Bool

    private var canSend: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter new email")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("A 6-digit verification code has been sent to your email. Enter it below to verify your identity and activate your wallet.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("", text: $email)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.black)
                .tint(Theme.accent)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { focused = false }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.98)) // #FAFAFA
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color(white: 0.898), lineWidth: 1) // #E5E5E5
                        )
                )

            Button {
                if canSend {
                    onSendCode(email)
                    dismiss()
                }
            } label: {
                Text("Send OTP Code")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        canSend ? Theme.accent : Theme.accent.opacity(0.45),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focused = true
            }
        }
    }
}
