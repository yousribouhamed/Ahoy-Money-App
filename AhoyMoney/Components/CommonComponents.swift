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
            .foregroundStyle(.white)
            .tint(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
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
            .foregroundStyle(.white)
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
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
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
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}
