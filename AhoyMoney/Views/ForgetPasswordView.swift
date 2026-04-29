import SwiftUI

struct ForgetPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    var onContinue: (String) -> Void = { _ in }

    @State private var email: String = ""
    @State private var showVerifySheet: Bool = false
    @FocusState private var emailFocused: Bool

    private var isValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Forget Password")
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
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 24) {
                    Text("Enter your email in order to recognise your account and we'll send OTP code to verify it")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 28)

                    VStack(spacing: 16) {
                        TextField(
                            "",
                            text: $email,
                            prompt: Text("Email").foregroundStyle(Theme.accent.opacity(0.7))
                        )
                        .textFieldStyle(.plain)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($emailFocused)
                        .submitLabel(.done)
                        .onSubmit { emailFocused = false }
                        .darkFieldStyle()

                        Button {
                            if isValid { showVerifySheet = true }
                        } label: {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(
                                    isValid ? Color.white : Color.white.opacity(0.45),
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isValid)
                    }
                }
                .padding(.horizontal, 22)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showVerifySheet) {
            VerifyEmailSheet(
                subtitle: "A 6-digit verification code has been sent to your email. Enter it below to verify your identity and reset your password",
                onVerify: { onContinue(email) }
            )
        }
    }
}
