import SwiftUI

struct VerifyingIdentityView: View {
    @Environment(\.dismiss) private var dismiss

    var onComplete: () -> Void = {}

    @State private var spin: Bool = false

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
                            onComplete()
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
                    // Progress: first 3 white (steps 1, 2 & 3 active), last 2 cyan.
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                    }

                    // Loading list.
                    VStack(alignment: .leading, spacing: 20) {
                        loaderRow("Verifying Your Identity")
                        loaderRow("Checking your documents")
                        loaderRow("Matching your selfie")

                        Text("This may take a few seconds. We're checking your ID and selfie to confirm everything matches.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                Spacer(minLength: 0)

                // Hero image.
                Image("verifying_ids")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }

    private func loaderRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(spin ? 360 : 0))
            }

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
