import SwiftUI

struct SetupWalletView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var onContinue: () -> Void = {}

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Setup Wallet")
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

                        Button {
                            onContinue()
                        } label: {
                            Text("Next")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 3/255, green: 1/255, blue: 38/255))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Theme.accent, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 24) {
                    // Progress: 5 segments, first white, rest cyan.
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                    }

                    // Step header.
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("1")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent, in: .circle)

                            Text("Scan your ID")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("To continue, please scan your Emirates ID for quick and secure identity verification.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                Spacer()

                // Hero image.
                Image("emirates_id")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)

                Spacer()

                // Caption + Continue button.
                VStack(spacing: 24) {
                    Text("We need to scan your Emirates ID to\nverify your identity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.white, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
