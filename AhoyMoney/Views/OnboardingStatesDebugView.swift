#if DEBUG
import SwiftUI

/// Every onboarding outcome, one tap away.
///
/// **Why this exists.** Five of the six outcomes can't be reached by using the
/// app. Four of them are back-office events — a reviewer asking for a document,
/// a reviewer declining, an automatic control firing — and in production they
/// arrive from a backend that doesn't exist yet. The fifth needs the identity
/// vendor to fail, and the mock always passes. Only "under review" is walkable,
/// by editing a field read off the Emirates ID.
///
/// So the screens were built and correct and nobody could look at them. This is
/// how they get reviewed and screenshotted before there's a backend to drive
/// them.
///
/// It opens each screen directly with representative data rather than mutating
/// the real store, so browsing the states can't strand the app in one. Wrapped
/// in `#if DEBUG` — it cannot ship.
struct OnboardingStatesDebugView: View {
    @Environment(OnboardingStore.self) private var onboarding

    /// What's being previewed full screen, if anything.
    @State private var presented: AnyIdentifiableView?

    private static let sampleRequest = InfoRequest(
        // A reviewer's own words, as the brief asks — not a template.
        note: "We need to see where your salary is paid in before we can finish your application. Please send a statement covering the last three months.",
        items: [
            RequestedItem(
                title: "Bank statement",
                detail: "The account your salary is paid into."
            )
        ]
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                note

                group("Waiting", subtitle: "Subtask 3 — reached two ways") {
                    row("Under review — risk factor",
                        detail: "A control fired. Generic wording.") {
                        UnderReviewView(since: threeHoursAgo, reason: .riskFactor)
                    }
                    row("Under review — edited details",
                        detail: "They corrected a misread field. Its own words.") {
                        UnderReviewView(since: threeHoursAgo, reason: .editedDetails)
                    }
                }

                group("The four exits", subtitle: "Subtask 5 — two end the journey, two don't") {
                    row("Identity capture failed",
                        detail: "Attempt 1 of \(onboarding.maxIdentityAttempts). Still inside the journey.") {
                        IdentityFailedView(attemptsUsed: 1, canRetry: true)
                    }
                    row("Identity capture failed — no retries left",
                        detail: "Attempts used up.") {
                        IdentityFailedView(attemptsUsed: onboarding.maxIdentityAttempts, canRetry: false)
                    }
                    row("System refused",
                        detail: "30-minute timer. Generic by design.") {
                        SystemRefusedView(retryFrom: inThirtyMinutes)
                    }
                    row("Compliance asks for a document",
                        detail: "Still under review — a request is not a status.") {
                        MoreInfoNeededView(request: Self.sampleRequest)
                    }
                    row("Compliance declines",
                        detail: "30 minutes, then a way back in.") {
                        RejectedView(reapplyFrom: inThirtyMinutes)
                    }
                }

                group("The happy path", subtitle: "The screens most people actually see") {
                    row("Create a passcode",
                        detail: "Step 5. Six digits, entered twice.") {
                        SetPasscodeView()
                    }
                    row("Wallet is open",
                        detail: "The arrival. No card yet — they make one.") {
                        WalletCreatedView()
                    }
                }

                group("Optional items", subtitle: "Neither blocks anything") {
                    row("Profile checklist",
                        detail: "Email and proof of address.") {
                        ProfileChecklistView()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .background(DarkGradientBackground())
        .navigationTitle("Onboarding states")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $presented) { entry in
            ZStack(alignment: .topTrailing) {
                entry.view

                // Every one of these screens hides the navigation bar, so the
                // only reliable way out is one we draw ourselves.
                Button { presented = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(11)
                        .background(.black.opacity(0.55), in: .circle)
                }
                .buttonStyle(.plain)
                // These screens draw their background past the safe area, so
                // the ZStack reaches the screen edge and an unpadded button
                // lands under the status bar.
                .safeAreaPadding(.top)
                .padding(.top, 6)
                .padding(.trailing, 16)
            }
        }
    }

    private var threeHoursAgo: Date { Date().addingTimeInterval(-3 * 3600) }
    private var inThirtyMinutes: Date { Date().addingTimeInterval(SystemRefusal.cooldown) }

    private var note: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Debug builds only. Opens each screen directly — nothing here changes your account.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardOverlay, in: .rect(cornerRadius: 14))
    }

    private func group<Content: View>(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(spacing: 0) { content() }
                .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }

    private func row<Destination: View>(
        _ title: String,
        detail: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        Button {
            presented = AnyIdentifiableView(id: title, view: AnyView(destination()))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Box so a heterogeneous set of screens can drive one `fullScreenCover`.
private struct AnyIdentifiableView: Identifiable {
    let id: String
    let view: AnyView
}
#endif
