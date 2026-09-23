import SwiftUI

/// Celebratory screen shown right after a virtual card is issued.
///
/// The new card flips and slides into view, balance is shown, and we offer
/// a primary "View card" CTA that takes the user straight to the detail view.
struct CardSuccessView: View {
    @Environment(\.dismiss) private var dismiss

    let card: VirtualCard
    /// Called when the user taps "Done" — usually pops the issuance stack.
    var onDone: () -> Void = {}

    @State private var animateIn: Bool = false
    @State private var goToDetail: Bool = false

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                // Animated check halo.
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 88, height: 88)
                        .scaleEffect(animateIn ? 1 : 0.5)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 56, height: 56)
                        .scaleEffect(animateIn ? 1 : 0.4)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(Theme.accentDeep)
                        .scaleEffect(animateIn ? 1 : 0.5)
                }
                .opacity(animateIn ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Your card is ready")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    // Wallet provisioning is out of scope for R0, so nothing
                    // here promises it. The second sentence is the last chance
                    // to say where the money comes from before the worker
                    // starts spending on a card they've just made.
                    Text("Use it online straight away. It spends from your wallet balance, the same as your other cards.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.center)
                }

                // Card flips into view, at the same width it had in the
                // preview a moment ago — it shouldn't shrink on arrival.
                Color.clear
                    .aspectRatio(340.0 / 212.0, contentMode: .fit)
                    .overlay {
                        GeometryReader { geo in
                            CardArtwork(card: card, size: geo.size, tiltEnabled: true)
                        }
                    }
                    .rotation3DEffect(
                        .degrees(animateIn ? 0 : 90),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .opacity(animateIn ? 1 : 0)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        goToDetail = true
                    } label: {
                        Text("View card")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.white, in: .capsule)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDone()
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 22)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Driven by an explicit flag rather than `NavigationLink(value:)`.
        // A value-based link needs a destination registered for the type on a
        // view that is still active in the stack; the rest of this app pushes
        // with `isPresented`, so this matches what already works here.
        .navigationDestination(isPresented: $goToDetail) {
            CardDetailView(cardId: card.id)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.05)) {
                animateIn = true
            }
        }
    }
}
