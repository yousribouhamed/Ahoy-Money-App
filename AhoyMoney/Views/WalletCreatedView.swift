import SwiftUI

struct WalletCreatedView: View {
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

                // Hero card.
                ZStack(alignment: .topLeading) {
                    Image("wallet_success")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 278)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Successfully")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Created.")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 28)
                    .padding(.leading, 24)
                }
                .padding(.horizontal, 18)
                .padding(.top, 36)

                Spacer()

                // Go to Wallet button.
                Button {
                    onContinue()
                } label: {
                    Text("Go to Wallet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.white, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 220)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
