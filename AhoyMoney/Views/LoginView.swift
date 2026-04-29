import SwiftUI

struct LoginView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable { case username, password }

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var focused: Field?

    private var isValid: Bool { true }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Login")
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

                // Form.
                VStack(spacing: 24) {
                    VStack(spacing: 28) {
                        VStack(spacing: 20) {
                            darkField(placeholder: "Username", text: $username, secure: false)
                                .focused($focused, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focused = .password }

                            AppPasswordField(
                                placeholder: "Password",
                                text: $password,
                                isVisible: $showPassword,
                                submitLabel: .done,
                                onSubmit: { focused = nil }
                            )
                            .focused($focused, equals: .password)
                        }

                        HStack {
                            Spacer()
                            Button {
                                router.authPath.append(.forgetPassword)
                            } label: {
                                Text("Forgot Password?")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.subText)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    PrimaryWhiteButton(title: "Continue", enabled: isValid) {
                        BiometricAuth.authenticate(reason: "Authenticate to access your wallet") { success in
                            if success { router.isAuthenticated = true }
                        }
                    }

                    Button {
                        router.authPath = [.register]
                    } label: {
                        Text("Don't have an account? Create account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 19)
                .padding(.top, 40)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func darkField(placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7)))
                    .textContentType(.password)
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7)))
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
        }
        .darkFieldStyle()
    }
}
