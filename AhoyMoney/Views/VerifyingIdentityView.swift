import SwiftUI

/// The KYC loader.
///
/// Not a step in the journey — the capture and the check belong to the vendor.
/// This covers the wait while the provider works, which is why it has no
/// forward action: it finishes on its own and routes to whichever of the three
/// outcomes came back.
///
/// The stages tick through in order rather than all spinning at once. Three
/// spinners that never resolve tell the customer nothing about whether anything
/// is happening, which on a slow check is when people force-quit.
struct VerifyingIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingStore.self) private var onboarding

    /// Passed — carry on to Fill Details.
    var onComplete: () -> Void = {}
    /// The face didn't match the document. Still inside the journey.
    var onCaptureFailed: () -> Void = {}
    /// An automatic control stopped it.
    var onRefused: () -> Void = {}

    /// Swappable so the uqudo SDK drops in without touching this screen.
    var verifier: IdentityVerifier = MockIdentityVerifier()

    private enum Stage: Int, CaseIterable, Identifiable {
        case reading, checking, matching
        var id: Int { rawValue }

        var title: String {
            switch self {
            case .reading:  return "Reading your Emirates ID"
            case .checking: return "Checking the document"
            case .matching: return "Matching your selfie"
            }
        }
    }

    @State private var stage: Int = 0
    @State private var finished = false

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                topBar

                VStack(alignment: .leading, spacing: 26) {
                    OnboardingStepper(step: 3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Checking your identity")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        // No promise about how long. The provider sets the
                        // pace, and "a few seconds" that turns into thirty is
                        // worse than saying nothing.
                        Text("This usually doesn't take long. Please keep the app open while we finish.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Stage.allCases) { s in
                            stageRow(s)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                Spacer(minLength: 0)

                Image("verifying_ids")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await run()
        }
    }

    /// Back stays as an escape hatch if the provider hangs, but there's no
    /// forward action — this screen isn't something you can skip past.
    private var topBar: some View {
        ZStack {
            Text("Setup Wallet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack {
                Button { dismiss() } label: {
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
    }

    private func stageRow(_ s: Stage) -> some View {
        let done = finished || s.rawValue < stage
        let active = !finished && s.rawValue == stage

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.strokeSubtle, lineWidth: 2)
                    .frame(width: 26, height: 26)

                if done {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.accentDeep)
                } else if active {
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 26, height: 26)
                        .rotationEffect(.degrees(active ? 360 : 0))
                        .animation(
                            .linear(duration: 0.9).repeatForever(autoreverses: false),
                            value: active
                        )
                }
            }

            Text(s.title)
                .font(.system(size: 17, weight: done || active ? .semibold : .medium))
                .foregroundStyle(done || active ? Theme.textPrimary : Theme.textSecondary)

            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.25), value: done)
    }

    /// Walks the stages while the check runs, then routes on the outcome.
    private func run() async {
        // Advance the visible stages so the screen reflects progress even
        // though the provider reports only a final result.
        let walker = Task {
            for step in 1...Stage.allCases.count {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation { stage = step }
            }
        }

        await onboarding.runIdentityCheck(using: verifier)
        walker.cancel()

        withAnimation { finished = true }
        try? await Task.sleep(for: .milliseconds(350))

        switch onboarding.identityOutcome {
        case .passed:
            onComplete()
        case .failed:
            onCaptureFailed()
        case .notStarted:
            // A refusal clears the outcome rather than failing it.
            onboarding.systemRefusal == nil ? onComplete() : onRefused()
        }
    }
}

#Preview("KYC loader") {
    VerifyingIdentityView()
        .environment(OnboardingStore())
}
