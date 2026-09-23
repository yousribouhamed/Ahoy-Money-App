import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared shell

/// Common layout for the exits, so four screens a customer meets on a bad day
/// can't drift apart in tone or structure.
private struct FailureShell<Content: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let body1: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .frame(width: 76, height: 76)
                        Image(systemName: icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .padding(.top, 20)

                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(body1)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Countdown

/// A visible wait, for the two exits that carry one.
///
/// Counting down beats a disabled button with no explanation — the customer can
/// see that waiting is the mechanism rather than guessing the app is broken.
private struct RetryCountdown: View {
    let until: Date
    let label: String
    let action: () -> Void

    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remaining: TimeInterval { max(0, until.timeIntervalSince(now)) }
    private var ready: Bool { remaining <= 0 }

    var body: some View {
        VStack(spacing: 10) {
            if ready {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .semibold))
                    Text("You can try again in \(formatted)")
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Theme.cardOverlay, in: .capsule)
            }
        }
        .onReceive(tick) { now = $0 }
    }

    private var formatted: String {
        let total = Int(remaining.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - 1. Identity capture failed

/// uqudo couldn't match the face to the document.
///
/// The customer is **still inside the journey** — this is a retry, not an exit.
/// Deliberately doesn't look like a decline: if the two looked alike, people
/// would give up on something fixable.
struct IdentityFailedView: View {
    @Environment(OnboardingStore.self) private var onboarding

    let attemptsUsed: Int
    let canRetry: Bool
    var onRetry: () -> Void = {}

    /// Optional override. Left nil, the button opens live chat itself — it used
    /// to default to an empty closure, which meant "Contact support" did
    /// nothing at all three of its call sites and the only exit from this
    /// screen was the back gesture.
    var onContactSupport: (() -> Void)?

    @State private var showChat = false

    private var attemptsLeft: Int {
        max(0, onboarding.maxIdentityAttempts - attemptsUsed)
    }

    var body: some View {
        FailureShell(
            icon: "faceid",
            tint: Theme.warning,
            title: "We could not match your face to your document",
            body1: canRetry
                ? "Try again in better light."
                // Doesn't claim anyone is already looking — whether this
                // escalates on its own is still undecided, and promising a
                // reviewer who may not exist is worse than under-promising.
                // Support is a real next step, so the button is the answer to
                // the sentence above it.
                : "We've tried the most times we can, and it still hasn't worked. Support can sort this out with you."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if canRetry {
                    VStack(alignment: .leading, spacing: 10) {
                        tip("Face a window, or somewhere bright")
                        tip("Hold the phone at eye level")
                        tip("Take off glasses, a hat or a mask")
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: .rect(cornerRadius: 14))

                    // The attempt number is shown rather than counted silently.
                    HStack(spacing: 6) {
                        Text("Attempt \(attemptsUsed) of \(onboarding.maxIdentityAttempts)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(attemptsLeft == 1 ? "· one more try" : "· \(attemptsLeft) tries left")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    PrimaryWhiteButton(title: "Try again", enabled: true) {
                        onboarding.retryIdentity()
                        onRetry()
                    }
                } else {
                    Button {
                        if let onContactSupport { onContactSupport() } else { showChat = true }
                    } label: {
                        Text("Contact support")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accentDeep)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Theme.accent, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .sheet(isPresented: $showChat) {
            LiveChatView()
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 2. The system refuses

/// An automatic control stopped it. No queue, no reviewer, no waiting list —
/// just a timer.
///
/// **The copy has to stay generic.** This one screen covers a blurred
/// photograph and a sanctions match, so it cannot hint at which. Telling the
/// customer to check their document would help in one case and tip them off in
/// the other. Often the fix genuinely is a better photograph, which is why the
/// retry matters at all.
struct SystemRefusedView: View {
    @Environment(OnboardingStore.self) private var onboarding

    let retryFrom: Date
    var onRetry: () -> Void = {}
    var onContactSupport: () -> Void = {}

    var body: some View {
        FailureShell(
            icon: "exclamationmark.octagon",
            tint: Theme.warning,
            // Draft copy from the ticket — pending Compliance sign-off.
            title: "We cannot continue right now",
            body1: "We are not able to set up your account at the moment. You can try again shortly."
        ) {
            VStack(spacing: 10) {
                RetryCountdown(until: retryFrom, label: "Try again") {
                    onboarding.clearSystemRefusal()
                    onRetry()
                }

                Button(action: onContactSupport) {
                    Text("Contact support")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - 3. Compliance asks for something

/// The ordinary outcome of a review, not a rare one.
///
/// The customer is **still under review** — an open request is not a status, so
/// this screen says so rather than presenting itself as a new verdict.
///
/// Shows the reviewer's reason in their own words: a template here would lose
/// the one piece of information that tells the customer what to actually send.
///
/// **What the redesign fixed.** The old version stacked four cards of near-equal
/// weight and never said what a good document looked like. That's the expensive
/// gap: send the wrong thing and the review bounces, and the customer waits
/// another day to find out. Crypto.com, Cleo, Wise and Binance all state the
/// acceptance criteria *before* the upload, so that's what this does — and the
/// upload target is now the whole dashed area rather than a small "Add" link
/// beside it.
struct MoreInfoNeededView: View {
    @Environment(OnboardingStore.self) private var onboarding

    let request: InfoRequest
    var onSubmitted: () -> Void = {}

    /// Files attached per requested item. Several per item is the normal case:
    /// "the last three months" is one ask and three documents.
    @State private var files: [UUID: [String]] = [:]
    @State private var importingFor: RequestedItem? = nil
    @State private var attemptedSend = false
    @State private var fileCounter = 0

    private func files(for item: RequestedItem) -> [String] { files[item.id] ?? [] }
    private var allSupplied: Bool { request.items.allSatisfy { !files(for: $0).isEmpty } }
    private var outstanding: Int { request.items.filter { files(for: $0).isEmpty }.count }

    var body: some View {
        FailureShell(
            icon: "tray.and.arrow.up",
            tint: Theme.accent,
            title: "We need one more thing",
            body1: request.items.count == 1
                ? "Compliance has asked for a document before they can finish your review."
                : "Compliance has asked for a few documents before they can finish your review."
        ) {
            VStack(alignment: .leading, spacing: 22) {
                stillOpenPill
                reviewerNote

                ForEach(request.items) { item in
                    documentBlock(item)
                }

                sendBlock
            }
            .padding(.top, 4)
        }
        .fileImporter(
            isPresented: Binding(
                get: { importingFor != nil },
                set: { if !$0 { importingFor = nil } }
            ),
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: true
        ) { result in
            if case let .success(urls) = result, let item = importingFor {
                let names = urls.map(\.lastPathComponent)
                files[item.id, default: []].append(contentsOf: names.isEmpty
                    ? ["Document \(fileCounter + 1)"] : names)
                fileCounter += names.count
                attemptedSend = false
            }
            importingFor = nil
        }
    }

    /// Still under review. Said plainly, because a request landing in the app
    /// reads as a rejection otherwise.
    private var stillOpenPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 12, weight: .semibold))
            Text("Your application is still open")
                .font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.accent)
        .padding(12)
        .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    /// The reviewer's own words, quoted rather than paraphrased.
    private var reviewerNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT THEY ASKED FOR")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
            Text(request.note)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 3)
        }
        // Clipped to the card's own shape so the bar sits inside it and follows
        // the rounded corners. As a bare overlay it ran the full height and
        // stuck out past the curve at the top and bottom.
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - One document

    private func documentBlock(_ item: RequestedItem) -> some View {
        let added = files(for: item)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Files already attached.
            if !added.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(added.enumerated()), id: \.offset) { index, name in
                        fileRow(name) {
                            files[item.id]?.remove(at: index)
                        }
                    }
                }
            }

            addZone(item, hasFiles: !added.isEmpty)

            // The only guidance that's ours. What the document must *contain*
            // is in the reviewer's note — they write it as free text, so there
            // is nothing structured for us to list.
            Text(RequestedItem.fileGuidance)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One attached file, removable. Says it's attached and nothing about what
    /// happens to it — that part is ours, not theirs.
    private func fileRow(_ name: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(8)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(name)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardOverlay, in: .rect(cornerRadius: 14))
    }

    /// The whole area is the target. Stays available after the first file,
    /// because one request often means several documents — three months of
    /// statements is one ask.
    private func addZone(_ item: RequestedItem, hasFiles: Bool) -> some View {
        let missing = attemptedSend && !hasFiles

        return Button {
            importingFor = item
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 42, height: 42)
                    Image(systemName: hasFiles ? "plus" : "arrow.up.doc")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasFiles ? "Add another document" : "Add this document")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Take a photo or choose a file")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        missing ? Theme.warning : Theme.strokeSubtle,
                        style: StrokeStyle(lineWidth: missing ? 1.5 : 1, dash: [6, 4])
                    )
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Send

    private var sendBlock: some View {
        VStack(spacing: 10) {
            // Live rather than disabled. A dead button can't say what's
            // missing, and here the thing that's missing is the whole task.
            Button {
                guard allSupplied else {
                    withAnimation(.easeOut(duration: 0.15)) { attemptedSend = true }
                    return
                }
                onSubmitted()
            } label: {
                // "One still to add" read as a status line rather than
                // something you could press. This says what tapping does.
                Text(allSupplied
                     ? (request.items.count == 1 ? "Send this in" : "Send these in")
                     : (outstanding == 1 ? "Add your document first" : "Add \(outstanding) documents first"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        allSupplied ? Color.white : Color.white.opacity(0.35),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)

            // What happens next. The brief says supplying it keeps the same
            // reviewer and doesn't restart the clock — worth saying, because
            // the fear is that sending something resets the wait.
            Text("It goes back to the same reviewer. You won't start again.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}

struct RejectedView: View {
    let reapplyFrom: Date
    var onReapply: () -> Void = {}
    var onContactSupport: () -> Void = {}

    var body: some View {
        FailureShell(
            icon: "xmark.circle",
            tint: Color(red: 1.0, green: 0.42, blue: 0.42),
            // Draft copy from the ticket — pending Compliance sign-off.
            title: "We cannot open an account for you",
            body1: "We have looked at your application and we are not able to continue with it. We are not able to explain why."
        ) {
            VStack(spacing: 10) {
                RetryCountdown(until: reapplyFrom, label: "Apply again", action: onReapply)

                Button(action: onContactSupport) {
                    Text("Contact support")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Previews

#Preview("1 · Capture failed") {
    IdentityFailedView(attemptsUsed: 1, canRetry: true)
        .environment(OnboardingStore())
}

#Preview("2 · System refuses") {
    SystemRefusedView(retryFrom: Date().addingTimeInterval(30 * 60))
        .environment(OnboardingStore())
}

#Preview("3 · Compliance asks") {
    MoreInfoNeededView(
        request: InfoRequest(
            note: "The address on the document you sent doesn't match the one you typed. Could you send something more recent, dated in the last three months?",
            items: [
                RequestedItem(title: "A recent proof of address", detail: "A bill or tenancy contract from the last 3 months")
            ]
        )
    )
    .environment(OnboardingStore())
}

#Preview("4 · Declined") {
    RejectedView(reapplyFrom: Date().addingTimeInterval(30 * 60))
        .environment(OnboardingStore())
}
