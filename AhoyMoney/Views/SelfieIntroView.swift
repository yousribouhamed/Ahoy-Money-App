import SwiftUI

struct SelfieIntroView: View {
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
                        // Balances the back button so the title stays
                        // centred. The forward action lives at the bottom
                        // of the screen — a second one up here competed
                        // with it and let people skip a step.
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 24) {
                    // Progress: first 2 white (steps 1 & 2 active), last 3 cyan.
                    OnboardingStepper(step: 2)

                    // Step header.
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text("2")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent, in: .circle)

                            Text("Let's Take a Selfie")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                        }

                        Text("Before you take your selfie, please remove your glasses, hat, face mask or any other accessories. These make it harder to identify you.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Examples illustration.
                    Image("selfie_examples")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(Color.white, in: .rect(cornerRadius: 8))

                    // Next button.
                    Button {
                        onContinue()
                    } label: {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.white, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
