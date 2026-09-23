import SwiftUI
import UIKit

/// Step 5 — the last step in the journey.
///
/// Six digits, entered twice. There is nothing after this but the app: the
/// approve-or-review decision happens once the passcode is set, so this screen
/// is the customer's last action rather than a gate in the middle.
///
/// Separate from the account password set at registration. The password gets
/// them into the account; this is what they'll use every day and to approve
/// payments, which is why it's short and numeric.
///
/// **Why a keypad we draw ourselves.** This used to be an invisible `TextField`
/// with `.keyboardType(.numberPad)`, with the dots as the only visible sign
/// anything was happening. That has three problems for a passcode specifically:
/// the system keyboard can be dismissed, leaving a screen with no way in except
/// tapping the dots; a text field accepts paste and third-party keyboards, which
/// is not what you want guarding payments; and the layout jumps as the keyboard
/// animates. Every comparable app — Revolut, Chase, Klarna, Airwallex, Tabby —
/// draws its own keypad. It also means the digits sit at a fixed position, which
/// matters when someone is entering the same code twice from muscle memory.
struct SetPasscodeView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called once both entries match.
    var onComplete: () -> Void = {}

    private enum Stage { case create, confirm }

    @State private var stage: Stage = .create
    @State private var first: String = ""
    @State private var second: String = ""
    @State private var problem: Problem?
    @State private var shake: CGFloat = 0

    private static let length = 6

    /// What went wrong, if anything. One type rather than a set of booleans so
    /// two errors can't be on screen at once.
    private enum Problem: Equatable {
        case mismatch
        case tooGuessable

        var message: String {
            switch self {
            case .mismatch:      return "Those didn't match. Start again with a new passcode."
            case .tooGuessable:  return "That one's too easy to guess. Try digits that aren't repeated or in order."
            }
        }
    }

    private var current: String { stage == .create ? first : second }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                topBar

                VStack(alignment: .leading, spacing: 24) {
                    OnboardingStepper(step: 5)
                    header
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)

                // Dots are centred while the title stays left-aligned. They line
                // up with the keypad below, which is what the eye tracks between
                // while typing.
                dots
                    .padding(.top, 36)
                    .offset(x: shake)

                errorLine
                    .padding(.horizontal, 30)
                    .padding(.top, 14)

                Spacer(minLength: 12)

                keypad
                    .padding(.horizontal, 34)

                hint
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Chrome

    /// Back means "start over" on the confirm stage. Without it, someone who
    /// realises they mistyped had to enter six wrong digits on purpose and wait
    /// to be told off before they could try again.
    private var topBar: some View {
        ZStack {
            Text("Setup Wallet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack {
                Button {
                    if stage == .confirm { startOver() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
                .accessibilityLabel(stage == .confirm ? "Start again" : "Back")

                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("5")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 24, height: 24)
                    .background(Theme.accent, in: .circle)

                Text(stage == .create ? "Create a passcode" : "Enter it again")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text(stage == .create
                 ? "Six digits. You'll use this to open the app and to approve payments."
                 : "Just to make sure we've got it right.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Dots

    private var dots: some View {
        HStack(spacing: 16) {
            ForEach(0..<Self.length, id: \.self) { index in
                let filled = index < current.count
                Circle()
                    .fill(filled ? Theme.accent : Color.clear)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle().strokeBorder(
                            filled ? Color.clear : Theme.strokeSubtle,
                            lineWidth: 1.5
                        )
                    )
                    .scaleEffect(filled ? 1 : 0.82)
                    .animation(.spring(response: 0.22, dampingFraction: 0.6), value: filled)
            }
        }
        .frame(maxWidth: .infinity)
        // Six unlabelled circles say nothing to VoiceOver. State the count.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stage == .create ? "Create a passcode" : "Confirm your passcode")
        .accessibilityValue("\(current.count) of \(Self.length) digits entered")
    }

    @ViewBuilder
    private var errorLine: some View {
        if let problem {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(problem.message)
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
            .multilineTextAlignment(.leading)
            .transition(.opacity)
        } else {
            // Holds the space so the keypad doesn't jump when an error appears.
            Color.clear.frame(height: 18)
        }
    }

    @ViewBuilder
    private var hint: some View {
        if stage == .create && problem == nil {
            // Said before it's needed rather than only after a rejection —
            // Chase and Klarna both put this guidance up front.
            Text("Avoid repeats and runs like 111111 or 123456.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(height: 16)
        }
    }

    // MARK: - Keypad

    private var keypad: some View {
        VStack(spacing: 14) {
            ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]], id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(row, id: \.self) { digit(  $0) }
                }
            }
            HStack(spacing: 22) {
                // Keeps 0 in the centre column, where every phone keypad has it.
                Color.clear.frame(width: 72, height: 72)
                digit("0")
                deleteKey
            }
        }
    }

    private func digit(_ value: String) -> some View {
        Button {
            append(value)
        } label: {
            Text(value)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(Theme.cardOverlay)
                        .overlay(Circle().strokeBorder(Theme.strokeSubtle, lineWidth: 1))
                )
        }
        .buttonStyle(KeyStyle())
    }

    private var deleteKey: some View {
        Button(action: backspace) {
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(current.isEmpty ? Theme.textSecondary.opacity(0.4) : Theme.textPrimary)
                .frame(width: 72, height: 72)
        }
        .buttonStyle(KeyStyle())
        .disabled(current.isEmpty)
        .accessibilityLabel("Delete")
    }

    /// Presses press. A key that doesn't move under the finger reads as broken,
    /// and on a keypad you're watching the dots rather than the key.
    private struct KeyStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .opacity(configuration.isPressed ? 0.7 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    // MARK: - Entry

    private func append(_ value: String) {
        guard current.count < Self.length else { return }
        Haptics.tap()

        if stage == .create {
            problem = nil
            first += value
            guard first.count == Self.length else { return }

            guard !Self.isTooGuessable(first) else {
                fail(.tooGuessable)
                return
            }
            // Moves on without a button — a full passcode is the only signal
            // needed, and a Continue button here is one tap of pure ceremony.
            advanceToConfirm()
        } else {
            second += value
            guard second.count == Self.length else { return }
            check()
        }
    }

    private func backspace() {
        guard !current.isEmpty else { return }
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.12)) { problem = nil }
        if stage == .create { first.removeLast() } else { second.removeLast() }
    }

    private func advanceToConfirm() {
        // A beat before the switch, so the sixth dot is seen to fill rather than
        // the screen changing out from under the finger.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.22)) { stage = .confirm }
        }
    }

    private func check() {
        guard first == second else {
            fail(.mismatch)
            return
        }
        Haptics.success()
        onComplete()
    }

    /// Both failures land here: say what's wrong, shake, then reset to a clean
    /// first entry. Correcting half of a wrong passcode isn't a thing we want to
    /// support — the customer should be sure of all six.
    private func fail(_ reason: Problem) {
        Haptics.error()
        withAnimation(.easeOut(duration: 0.15)) { problem = reason }
        shakeDots()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { startOver() }
    }

    private func startOver() {
        withAnimation(.easeInOut(duration: 0.22)) {
            first = ""
            second = ""
            stage = .create
        }
    }

    /// The old version animated `shake` from 0 to 0, so nothing ever moved.
    private func shakeDots() {
        withAnimation(.linear(duration: 0.055).repeatCount(6, autoreverses: true)) {
            shake = 9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { shake = 0 }
    }

    /// Rejects the passcodes that get guessed first: all one digit, or a run in
    /// either direction. Not a strength meter — six digits guarding payments
    /// just shouldn't be `111111`.
    private static func isTooGuessable(_ code: String) -> Bool {
        let digits = code.compactMap(\.wholeNumberValue)
        guard digits.count == length else { return false }
        if Set(digits).count == 1 { return true }
        let pairs = zip(digits, digits.dropFirst())
        if pairs.allSatisfy({ $1 == $0 + 1 }) { return true }
        if pairs.allSatisfy({ $1 == $0 - 1 }) { return true }
        return false
    }
}

/// Small wrapper so the call sites read as intent rather than UIKit noise.
private enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

#Preview("Create") {
    SetPasscodeView()
}
