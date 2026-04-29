import SwiftUI

struct VerifyOtpView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var showTerms: Bool = false

    private var code: String { digits.joined() }
    private var isValid: Bool { code.count == 6 }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Register")
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
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Text("Pending Activation")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.warning)
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

                    PrimaryWhiteButton(title: "Verify & Activate", enabled: isValid) {
                        focusedIndex = nil
                        showTerms = true
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
}

private struct OTPBox: View {
    @Binding var text: String
    var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .tint(Theme.accent)
            .frame(width: 52, height: 52)
            .background(Theme.card, in: .rect(cornerRadius: 16))
    }
}
