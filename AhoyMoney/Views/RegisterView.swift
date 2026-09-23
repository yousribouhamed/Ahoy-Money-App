import SwiftUI

struct RegisterView: View {
    @Environment(AppRouter.self) private var router
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable { case email, phone, password, confirm }

    @State private var email: String = ""
    @State private var code: String = "+971"
    @State private var phone: String = ""
    @State private var showingCountrySheet: Bool = false
    @State private var showInvite: Bool = false
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirm: Bool = false
    @FocusState private var focused: Field?

    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    // Password is set here rather than after identity: the account exists from
    // this step, so it needs credentials from this step.
    private var isValid: Bool {
        email.contains("@") &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty &&
        PasswordRules.isValid(password) &&
        passwordsMatch
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Register")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

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

                // Form block.
                VStack(spacing: 24) {
                    // Progress segments — step 1 of 2 complete, step 2 active.
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 8)
                        Capsule().fill(Theme.accent).frame(height: 8)
                    }

                    VStack(spacing: 20) {
                        darkField(placeholder: "Email Address", text: $email, secure: false)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .focused($focused, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focused = .phone }

                        HStack(spacing: 12) {
                            Button {
                                showingCountrySheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text(code.isEmpty ? "+Code" : code)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(code.isEmpty ? Theme.subText : .white)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(minWidth: 72)
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .background(Theme.card, in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)

                            darkField(placeholder: "Phone Number", text: $phone, secure: false)
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                                .focused($focused, equals: .phone)
                                .submitLabel(.next)
                                .onSubmit { focused = .password }
                        }

                        AppPasswordField(
                            placeholder: "Password",
                            text: $password,
                            isVisible: $showPassword,
                            submitLabel: .next,
                            onSubmit: { focused = .confirm }
                        )
                        .focused($focused, equals: .password)

                        // Always on screen, not revealed by failing. Someone
                        // should be able to meet the rule first time.
                        PasswordRequirementList(password: password)
                            .padding(.horizontal, 4)

                        AppPasswordField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            isVisible: $showConfirm,
                            submitLabel: .done,
                            onSubmit: { focused = nil }
                        )
                        .focused($focused, equals: .confirm)

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Both passwords need to match.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                                .padding(.horizontal, 4)
                        }
                    }

                    // Where the two paths fork. An invited worker's employer
                    // is known from here on; everyone else is asked for theirs
                    // on Fill Details.
                    inviteRow

                    PrimaryWhiteButton(title: "Continue", enabled: isValid) {
                        if onboarding.enrolmentPath == nil {
                            onboarding.useStandalonePath()
                        }
                        router.authPath.append(.verifyOtp)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 40)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showInvite) {
            InviteCodeSheet { employer in
                onboarding.applyInvite(employer)
            }
        }
        .sheet(isPresented: $showingCountrySheet) {
            CountryCodeSheet { country in
                code = country.code
            }
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
    }

    /// Shown as a quiet secondary route — most people sign up on their own,
    /// and an invited worker is looking for this.
    @ViewBuilder
    private var inviteRow: some View {
        if let employer = onboarding.enrolmentPath?.employer {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invited by \(employer.name)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("We'll fill your employer in for you")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Button("Change") { showInvite = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.accent.opacity(0.10), in: .rect(cornerRadius: 14))
        } else {
            Button {
                showInvite = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 14, weight: .semibold))
                    Text("I have an invite code from my employer")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Theme.cardOverlay, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func darkField(placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7)))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
        }
        .darkFieldStyle()
    }
}
