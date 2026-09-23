import SwiftUI
import UniformTypeIdentifiers

// Email verification and proof of address are optional in-app items. They are
// deliberately NOT part of the onboarding journey — neither blocks the wallet,
// the card, or the Compliance decision. They live in the profile checklist,
// findable without being a nag.

// MARK: - Checklist card

/// One outstanding item, used by both the last step and the profile checklist
/// so they can't describe the same thing differently.
struct ChecklistCard: View {
    let item: ChecklistItem
    let isDone: Bool
    var statusNote: String? = nil
    /// The file that was uploaded, once there is one.
    var uploadedFile: String? = nil
    var onReplace: (() -> Void)? = nil
    let action: () -> Void
    let actionLabel: () -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDone ? Theme.accent.opacity(0.18) : Theme.cardOverlay)
                        .frame(width: 40, height: 40)
                    Image(systemName: isDone ? "checkmark" : item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDone ? Theme.accent : Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(isDone ? "Done" : item.detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isDone ? Theme.accent : Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            // Uploaded: show the document itself rather than a tick.
            //
            // Says we have it and nothing more. What happens to it next is our
            // business, and "a reviewer will check it" would put the customer
            // back in a queue they didn't ask about for something optional.
            if let uploadedFile {
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(uploadedFile)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("We've got it")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    if let onReplace {
                        Button("Replace", action: onReplace)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardOverlay, in: .rect(cornerRadius: 12))
            }

            if let statusNote, !isDone {
                Text(statusNote)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !isDone {
                Button(action: action) {
                    Text(actionLabel())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isDone ? Theme.accent.opacity(0.3) : Theme.strokeSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Under review

/// The exception, not the rule.
///
/// Most customers are approved instantly and never see this. The ones who do
/// have just photographed a document and taken a selfie — handled badly this is
/// where they drop off and open a support ticket. Few people reach it, which is
/// exactly why it has to be good.
///
/// **Nothing is issued while this is open.** No wallet, no card. So the screen
/// doesn't offer either.
struct UnderReviewView: View {
    @Environment(OnboardingStore.self) private var onboarding

    var since: Date
    var reason: ReviewReason

    /// Shown only when this screen is the end of onboarding. Reached from the
    /// dashboard pill the customer is already inside the app, and a button
    /// offering to take them there would be nonsense.
    var onExplore: (() -> Void)?

    @State private var animateIn = false

    /// Roughly how far through the stated window we are. A rough position is
    /// more use than a spinner, which says only that something is happening.
    private var progress: Double {
        let window = Double(OnboardingStore.reviewWindowHours) * 3600
        return min(max(Date().timeIntervalSince(since) / window, 0.04), 1)
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.10))
                        .frame(width: 116, height: 116)
                    Circle()
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 84, height: 84)
                    Image(systemName: reason == .editedDetails ? "checkmark.circle" : "hourglass")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .scaleEffect(animateIn ? 1 : 0.6)
                .opacity(animateIn ? 1 : 0)
                .padding(.bottom, 22)

                // The edit route gets its own words: they did the right thing.
                Text(reason.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)

                Text(reason.detail)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
                    .padding(.top, 8)

                progressBlock
                    .padding(.horizontal, 22)
                    .padding(.top, 26)

                Spacer(minLength: 0)

                // The way out of a dead end.
                //
                // The wait is real and nothing speeds it up, but leaving someone
                // on a screen with no action for 24 hours after they've just
                // photographed their passport is how you lose them. Letting them
                // in costs nothing: the wallet is shut either way, and the app
                // says so plainly once they're inside.
                if let onExplore {
                    PrimaryWhiteButton(title: "Look around while you wait", enabled: true) {
                        onExplore()
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                }

                // Nothing to press *about the review itself*. Saying so beats
                // leaving someone hunting for a way to hurry it along.
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 13, weight: .semibold))
                        Text("We'll notify you the moment it's done")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textPrimary)

                    Text("There's nothing you need to do, and nothing that speeds it up.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .opacity(animateIn ? 1 : 0)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { animateIn = true }
        }
    }

    /// States the expectation without drawing a countdown.
    ///
    /// There was a progress bar here. It was wrong twice over: the window is
    /// working days rather than wall-clock hours, so the bar filled at the
    /// wrong rate; and once it reached the end it just sat there, turning "this
    /// is on track" into "this is overdue" for anyone whose file took longer.
    /// A bar can only promise a finish time we don't control.
    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Usually within one working day")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(Self.relative.localizedString(for: since, relativeTo: Date()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text("We'll let you know as soon as it's done.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.strokeSubtle, lineWidth: 1)
        )
    }

    static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}

// MARK: - Profile checklist

/// Where deferred items live, and the route back to them.
///
/// Completing the last one is what finally sends the file — the same gate as
/// the end of the journey, reached from a different place.
struct ProfileChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingStore.self) private var onboarding

    @State private var showEmailSheet = false
    @State private var importingAddress = false
    @State private var addressFileName: String? = nil
    @State private var justSubmitted = false

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Finish your profile")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        // Neither item blocks the wallet, the card, or the
                        // Compliance decision. Findable, not a nag.
                        Text(onboarding.profileComplete
                             ? "That's everything — thanks."
                             : "Both are optional. Do them whenever suits you.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(ChecklistItem.allCases) { item in
                        ChecklistCard(
                            item: item,
                            isDone: !onboarding.outstanding.contains(item),
                            statusNote: note(for: item),
                            uploadedFile: item == .proofOfAddress ? addressFileName : nil,
                            onReplace: item == .proofOfAddress && addressFileName != nil
                                ? { importingAddress = true } : nil
                        ) {
                            handle(item)
                        } actionLabel: {
                            label(for: item)
                        }
                    }

                    if justSubmitted {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Sent for checking. We'll let you know when it's done.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ZStack {
                Text("Your profile")
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
            .padding(.bottom, 4)
            .headerBlurBackground()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEmailSheet) {
            VerifyEmailSheet(onVerify: { finish(.email) })
        }
        .fileImporter(
            isPresented: $importingAddress,
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                addressFileName = url.lastPathComponent
                finish(.proofOfAddress)
            }
        }
    }

    private func note(for item: ChecklistItem) -> String? {
        switch item {
        case .email:          return nil
        case .proofOfAddress: return nil
        }
    }

    private func label(for item: ChecklistItem) -> String {
        switch item {
        case .email:          return "Verify with a code"
        case .proofOfAddress: return addressFileName == nil ? "Choose a file" : "Done"
        }
    }

    private func handle(_ item: ChecklistItem) {
        switch item {
        case .email:
            showEmailSheet = true
        case .proofOfAddress:
            importingAddress = true
        }
    }

    private func finish(_ item: ChecklistItem) {
        let wasIncomplete = !onboarding.profileComplete
        onboarding.complete(item)
        if wasIncomplete && onboarding.profileComplete {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { justSubmitted = true }
        }
    }
}

// MARK: - Previews

// The two ways in. They read very differently on purpose.

#Preview("Waiting — risk factor") {
    UnderReviewView(since: Date().addingTimeInterval(-3 * 3600), reason: .riskFactor)
        .environment(OnboardingStore())
}

#Preview("Waiting — they edited their ID details") {
    UnderReviewView(since: Date().addingTimeInterval(-3 * 3600), reason: .editedDetails)
        .environment(OnboardingStore())
}
