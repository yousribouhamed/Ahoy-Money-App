import SwiftUI

struct VerifyOtpView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @Environment(OnboardingStore.self) private var onboarding

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var showTerms: Bool = false

    // MARK: OTP states
    //
    // Stand-in for the real verification call. The point of these states isn't
    // the check itself — it's that a wrong code, an expired code and a resend
    // each say something different, which none of them did before.
    private static let acceptedCode = "123456"
    private static let resendCooldown = 30
    private static let codeLifetime = 120

    @State private var errorMessage: String? = nil
    @State private var resendIn: Int = resendCooldown
    @State private var expiresIn: Int = codeLifetime
    @State private var shake: CGFloat = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var code: String { digits.joined() }
    private var isExpired: Bool { expiresIn <= 0 }
    private var isValid: Bool { code.count == 6 && !isExpired }

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

                VStack(alignment: .leading, spacing: 28) {
                    // Progress — both segments white (step 2 of 2).
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 8)
                        Capsule().fill(Color.white).frame(height: 8)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            HStack(spacing: 8) {
                                Text("4")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .frame(width: 24, height: 24)
                                    .background(Theme.accent, in: .circle)

                                Text("Identity Verification")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }

                            Spacer()
                        }

                        Text("A 6-digit verification code has been sent to your phone. Enter it below to verify your identity and activate your wallet.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.subText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // OTP boxes.
                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { i in
                            OTPBox(text: $digits[i], focused: focusedIndex == i)
                                .focused($focusedIndex, equals: i)
                                .onChange(of: digits[i]) { oldValue, newValue in
                                    let filtered = String(newValue.filter(\.isNumber).prefix(1))
                                    if filtered != newValue {
                                        digits[i] = filtered
                                        return
                                    }
                                    if !filtered.isEmpty, i < 5 {
                                        DispatchQueue.main.async { focusedIndex = i + 1 }
                                    } else if filtered.isEmpty, !oldValue.isEmpty, i > 0 {
                                        DispatchQueue.main.async { focusedIndex = i - 1 }
                                    }
                                }
                        }
                    }

                    // One line, and it changes with the state: an expired code
                    // needs a new one, a wrong code needs retyping. Saying
                    // "invalid" for both would send people to the wrong fix.
                    if let errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                    }

                    PrimaryWhiteButton(title: "Verify & Activate", enabled: isValid) {
                        submit()
                    }

                    resendRow
                }
                .onReceive(tick) { _ in
                    if resendIn > 0 { resendIn -= 1 }
                    if expiresIn > 0 {
                        expiresIn -= 1
                        if expiresIn == 0 {
                            errorMessage = "That code has expired. Send a new one to carry on."
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 40)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { focusedIndex = 0 }
        .sheet(isPresented: $showTerms) {
            TermsConditionsSheet(
                onAgree: {
                    router.authPath.append(.setupWallet)
                },
                onDecline: {
                    // Stay on OTP screen; user may try again or go back.
                }
            )
        }
    }

    // MARK: - Resend

    private var resendRow: some View {
        HStack(spacing: 4) {
            Text("Didn't get it?")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.subText)

            if resendIn > 0 {
                // Says when, not just "wait" — a countdown stops people
                // hammering the button.
                Text("Send again in \(resendIn)s")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            } else {
                Button("Send a new code") { resend() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
    }

    private func submit() {
        focusedIndex = nil

        guard !isExpired else {
            errorMessage = "That code has expired. Send a new one to carry on."
            return
        }

        guard code == Self.acceptedCode else {
            errorMessage = "That code isn't right. Check your messages and try again."
            digits = Array(repeating: "", count: 6)
            withAnimation(.default) { shake += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusedIndex = 0 }
            return
        }

        errorMessage = nil
        onboarding.phoneVerified = true
        showTerms = true
    }

    private func resend() {
        digits = Array(repeating: "", count: 6)
        errorMessage = nil
        resendIn = Self.resendCooldown
        expiresIn = Self.codeLifetime
        focusedIndex = 0
    }
}

private struct OTPBox: View {
    @Binding var text: String
    var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
            .frame(width: 52, height: 52)
            .background(Theme.card, in: .rect(cornerRadius: 16))
    }
}
