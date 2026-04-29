import SwiftUI

struct TransferView: View {
    @Environment(BeneficiaryStore.self) private var store

    @State private var showingBeneficiarySheet: Bool = false
    /// Set when the user picks a rail from the type sheet — drives the push
    /// into `AddBeneficiaryView`. Optional so we can use `navigationDestination(item:)`.
    @State private var pendingKind: BeneficiaryKind? = nil

    var body: some View {
        NavigationStack {
            content
                // Sheet first — it dismisses, then we push the destination.
                .sheet(isPresented: $showingBeneficiarySheet) {
                    BeneficiaryTypeSheet(onSelect: { kind in
                        // Slight delay so the sheet finishes dismissing cleanly
                        // before the navigation push animates in.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            pendingKind = kind
                        }
                    })
                }
                .navigationDestination(item: $pendingKind) { kind in
                    AddBeneficiaryView(kind: kind)
                }
                .navigationDestination(for: TransferRoute.self) { route in
                    switch route {
                    case .list:
                        BeneficiariesListView()
                    case .detail(let b):
                        BeneficiaryDetailView(beneficiary: b)
                    }
                }
        }
    }

    /// Routes inside the Send tab's `NavigationStack` — keeps both
    /// "see all" and per-contact detail flows in one place.
    private enum TransferRoute: Hashable {
        case list
        case detail(Beneficiary)
    }

    private var content: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 0) {
                    // Top bar.
                    HStack {
                        Text("Transfer")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            BiometricAuth.authenticate(reason: "Authenticate to add a new beneficiary") { success in
                                if success { showingBeneficiarySheet = true }
                            }
                        } label: {
                            Text("+ New Beneficiary")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(.white)
                    }
                    .padding(.horizontal, 19)
                    .padding(.top, 8)

                    VStack(spacing: 20) {
                        // Search field — iOS 26 liquid glass.
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Name, Phone, email")
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 17))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)

                        // Suggested — driven by the store so newly-added contacts
                        // appear at the front automatically.
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(store.items) { person in
                                        NavigationLink(value: TransferRoute.detail(person)) {
                                            SuggestedAvatar(person: person)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .scrollClipDisabled()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Quick actions — same destinations as the type sheet,
                        // so users have two equally-fast entry points.
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick actions")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            VStack(spacing: 16) {
                                QuickActionRow(emoji: "🌎",
                                               title: "Send international",
                                               subtitle: "Bank transfers to 200+ countries") {
                                    requestAdd(kind: .international)
                                }
                                QuickActionRow(emoji: "🇦🇪",
                                               title: "Send with in UAE",
                                               subtitle: "Transfer through UAE banks") {
                                    requestAdd(kind: .uae)
                                }
                                QuickActionRow(emoji: "💳",
                                               title: "Wallet transfer",
                                               subtitle: "From wallet to wallet") {
                                    requestAdd(kind: .wallet)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 12))
                        }

                        // Manage your transfers.
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Manage your transfers")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            VStack(spacing: 16) {
                                NavigationLink(value: TransferRoute.list) {
                                    ManageRow(icon: "person.2.fill", title: "Beneficiaries")
                                }
                                .buttonStyle(.plain)

                                ManageRow(icon: "calendar", title: "Upcoming transfers")
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.card, in: .rect(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Quick-action shortcut — gates with Face ID just like the top-right button.
    private func requestAdd(kind: BeneficiaryKind) {
        BiometricAuth.authenticate(reason: "Authenticate to add a new beneficiary") { success in
            if success {
                pendingKind = kind
            }
        }
    }
}

// MARK: - Suggested avatar (driven by Beneficiary).
private struct SuggestedAvatar: View {
    let person: Beneficiary

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(person.avatarBg)
                Text(person.initial)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 48, height: 48)

            Text(person.nickname ?? person.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
        }
        .frame(width: 64)
    }
}

// MARK: - Quick action row.
private struct QuickActionRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color(red: 0.012, green: 0.004, blue: 0.149)) // #030126
                    Text(emoji)
                        .font(.system(size: 20, weight: .semibold))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manage row.
private struct ManageRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color(red: 0.012, green: 0.004, blue: 0.149))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 44, height: 44)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}
