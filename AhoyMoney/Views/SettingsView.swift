import SwiftUI

struct SettingsView: View {
    @Environment(AppRouter.self) private var router

    @State private var twoFactor: Bool = true
    @State private var biometric: Bool = false
    @State private var pushNotifications: Bool = false
    @State private var autoTopUp: Bool = false
    @State private var darkMode: Bool = true
    @State private var dailyLimit: String = ""
    @State private var monthlyLimit: String = ""
    @State private var dailyLimitValue: Double = 30
    @State private var monthlyLimitValue: Double = 30

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 0) {
                    // Top bar.
                    ZStack {
                        Text("Wallet Setting")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)

                    HStack {
                        Spacer()

                        NavigationLink {
                            EditProfileView()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(.white)
                    }
                }
                    .padding(.horizontal, 19)
                    .padding(.top, 8)

                    VStack(spacing: 16) {
                        // Profile pill.
                        NavigationLink {
                            LanguagesView()
                        } label: {
                            ProfilePill()
                        }
                        .buttonStyle(.plain)
                        .scrollEdgeBlur()

                        // Profile Settings.
                        Section(title: "Profile Settings", trailingIcon: "square.and.pencil") {
                            VStack(spacing: 10) {
                                InfoRow(label: "Phone", value: "051542621")
                                InfoRow(label: "Country", value: "Algeria")
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 16))
                        }
                        .scrollEdgeBlur()

                        // App Setting — Language row + Dark Mode toggle.
                        Section(title: "App Setting") {
                            VStack(spacing: 10) {
                                NavigationLink {
                                    LanguagesView()
                                } label: {
                                    HStack {
                                        Text("Language")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.accent)
                                        Spacer()
                                        HStack(spacing: 8) {
                                            Text("English")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Theme.accent)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                HStack {
                                    Text("Dark Mode")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Toggle("", isOn: $darkMode).labelsHidden().tint(Theme.accent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 16))
                        }
                        .scrollEdgeBlur()

                        // Security.
                        Section(title: "Security") {
                            VStack(spacing: 16) {
                                ToggleRow(
                                    title: "Two-Factor Authentication",
                                    subtitle: "Require code for sensitive operations",
                                    isOn: $twoFactor
                                )
                                ToggleRow(
                                    title: "Biometric Authentication",
                                    subtitle: "Use fingerprint or face ID",
                                    isOn: Binding(
                                        get: { biometric },
                                        set: { newValue in
                                            // Both activation and deactivation require Face ID.
                                            BiometricAuth.authenticate(
                                                reason: newValue
                                                    ? "Authenticate to enable Biometric Authentication"
                                                    : "Authenticate to disable Biometric Authentication"
                                            ) { success in
                                                if success { biometric = newValue }
                                            }
                                        }
                                    )
                                )
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 16))
                        }
                        .scrollEdgeBlur()

                        // Notifications.
                        Section(title: "Notifications") {
                            VStack(spacing: 16) {
                                ToggleRow(
                                    title: "Push Notifications",
                                    subtitle: "Transaction alerts and updates",
                                    isOn: $pushNotifications
                                )
                                ToggleRow(
                                    title: "Auto Top-Up",
                                    subtitle: "Automatically top up when balance is low",
                                    isOn: $autoTopUp
                                )
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 16))
                        }
                        .scrollEdgeBlur()

                        // Transfer Limits — half-circle drag gauges.
                        Section(title: "Transfer Limits") {
                            HStack(spacing: 12) {
                                LimitGaugeCard(title: "Daily Limit", value: $dailyLimitValue)
                                LimitGaugeCard(title: "Monthly", value: $monthlyLimitValue)
                            }
                        }
                        .scrollEdgeBlur()

                        // Support.
                        Section(title: "Support") {
                            VStack(spacing: 0) {
                                NavigationLink {
                                    HelpCenterView()
                                } label: {
                                    SupportRow(
                                        icon: "questionmark.circle.fill",
                                        title: "Help Center",
                                        subtitle: "Articles, FAQs, contact us",
                                        showBadge: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 16))
                        }
                        .scrollEdgeBlur()

                        // Logout.
                        Button {
                            router.isAuthenticated = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                Text("Logout")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .scrollEdgeBlur()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
    }
}

// MARK: - Section wrapper.
private struct Section<Content: View>: View {
    let title: String
    var trailingIcon: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let icon = trailingIcon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            content
        }
    }
}

// MARK: - Profile pill.
private struct ProfilePill: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("settings_avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .background(Color(red: 1, green: 0.86, blue: 0.87))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 0) {
                Text("Yousri Bouhamed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("yybouhamed@gmail.com")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 65.5)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1), in: .rect(cornerRadius: 16))
    }
}

// MARK: - Support row.
/// Used by the Help Center entry in the Support section.
/// Renders an icon tile, title + subtitle, an optional "NEW" cyan badge,
/// and a trailing chevron — matching the rest of the settings rows.
private struct SupportRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var showBadge: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    if showBadge {
                        Text("NEW")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.5)
                            .foregroundStyle(Theme.accentDeep)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent, in: .capsule)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Info row.
private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Toggle row.
private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.accent)
            }
        }
        .tint(Theme.accent)
    }
}

// MARK: - Transfer limit row.
private struct LimitRow: View {
    let placeholder: String
    @Binding var value: String

    @State private var isEditing: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Label / editable field.
            Group {
                if isEditing {
                    TextField("", text: $value)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .tint(Theme.accent)
                        .focused($focused)
                } else {
                    Text(value.isEmpty ? placeholder : value)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(value.isEmpty ? Theme.subText : .white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Update / Save button.
            Button {
                if isEditing {
                    focused = false
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditing = false
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditing = true
                    }
                    DispatchQueue.main.async { focused = true }
                }
            } label: {
                Text(isEditing ? "Save" : "Update")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }
}
