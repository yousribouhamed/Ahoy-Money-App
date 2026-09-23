import SwiftUI

struct BackCircleButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.6), in: .circle)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryWhiteButton: View {
    let title: String
    var enabled: Bool = true
    var action: () -> Void
    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(enabled ? Color.white : Theme.disabled, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct PrimaryAccentButton: View {
    let title: String
    var enabled: Bool = true
    var action: () -> Void
    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(enabled ? Theme.accent : Theme.accent.opacity(0.4), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// White-glass field container — same look as the login password field.
struct DarkFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.textPrimary)
            .tint(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardOverlay)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.strokeSubtle, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func darkFieldStyle() -> some View { modifier(DarkFieldStyle()) }
}

/// Reusable password/secure text field with eye-toggle and the shared white-glass style.
struct AppPasswordField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isVisible {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7))
                    )
                } else {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7))
                    )
                }
            }
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.textPrimary)
            .tint(.white)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.strokeSubtle, lineWidth: 1)
                )
        )
    }
}

struct ProgressSegments: View {
    let total: Int
    let active: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < active ? Color.white : Theme.accent)
                    .frame(height: 8)
            }
        }
    }
}

struct StepBadge: View {
    let number: Int
    var body: some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: 24, height: 24)
            .background(Theme.accent, in: .circle)
    }
}

struct CheckboxToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isOn ? Theme.accent : Theme.grayBorder, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4).fill(isOn ? Theme.accent : Color.white)
                    )
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}

/// The Setup Wallet progress bar.
///
/// This used to be five hand-written capsules copied into every step screen,
/// which is how Fill Details ended up without one at all. Owning it here means
/// the count changes in one place if a step is ever added or dropped.
///
/// White is ground covered, accent is what's left.
struct OnboardingStepper: View {
    let step: Int
    var total: Int = 5

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < step ? Color.white : Theme.accent)
                    .frame(height: 6)
            }
        }
        // A bare row of capsules reads as nothing to VoiceOver, so state the
        // position rather than letting it announce five unlabelled shapes.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(total)")
    }
}

// MARK: - Empty state illustration

/// Artwork for an empty state.
///
/// One component rather than four `Image` call sites, because these are a
/// **set**: faceted low-poly objects, one hue, one camera angle, one light
/// direction. A set sized differently on each screen stops reading as one.
///
/// The assets are trimmed to their alpha bounds, so `size` is the object's
/// size rather than the size of a square it floats inside — the untrimmed
/// exports filled only ~58% of their frame and every call site would have had
/// to guess a correction factor.
///
/// Hidden from VoiceOver: the headline underneath already says what's missing,
/// and announcing "faceted card illustration" first is noise.
struct EmptyStateArt: View {
    let name: String
    var size: CGFloat = 132

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
