import SwiftUI

struct TransferView: View {
    @Environment(BeneficiaryStore.self) private var store

    @State private var showingBeneficiarySheet: Bool = false
    /// Set when the user picks a rail from the type sheet — drives the push
    /// into `AddBeneficiaryView`. Optional so we can use `navigationDestination(item:)`.
    @State private var pendingKind: BeneficiaryKind? = nil
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    /// Filters the suggested carousel by name / nickname / phone / email.
    private var filteredBeneficiaries: [Beneficiary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.items }
        return store.items.filter {
            $0.name.lowercased().contains(q)
            || ($0.nickname?.lowercased().contains(q) ?? false)
            || $0.subtitle.lowercased().contains(q)
            || ($0.phone?.contains(q) ?? false)
            || ($0.email?.lowercased().contains(q) ?? false)
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

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
                    case .upcoming:
                        UpcomingTransfersView()
                    }
                }
        }
    }

    /// Routes inside the Send tab's `NavigationStack` — keeps both
    /// "see all" and per-contact detail flows in one place.
    private enum TransferRoute: Hashable {
        case list
        case detail(Beneficiary)
        case upcoming
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
                            .foregroundStyle(Theme.textPrimary)

                        Spacer()

                        Button {
                            BiometricAuth.authenticate(reason: "Authenticate to add a new beneficiary") { success in
                                if success { showingBeneficiarySheet = true }
                            }
                        } label: {
                            Text("+ New Beneficiary")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .tint(.white)
                    }
                    .padding(.horizontal, 19)
                    .padding(.top, 8)

                    VStack(spacing: 20) {
                        // Search field — iOS 26 liquid glass, fully functional.
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.textSecondary)
                            TextField(
                                "",
                                text: $query,
                                prompt: Text("Name, phone, email")
                                    .foregroundStyle(Theme.textSecondary)
                            )
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Theme.textPrimary)
                            .tint(.white)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)

                            if !query.isEmpty {
                                Button { query = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .font(.system(size: 17))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)

                        // Searching → vertical list of matches; otherwise → suggested carousel.
                        if isSearching {
                            searchResults
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)

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
                        }

                        if !isSearching {
                            // Quick actions — same destinations as the type sheet,
                            // so users have two equally-fast entry points.
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quick actions")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)

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
                                    .foregroundStyle(Theme.textPrimary)

                                VStack(spacing: 16) {
                                    NavigationLink(value: TransferRoute.list) {
                                        ManageRow(icon: "person.2.fill", title: "Beneficiaries")
                                    }
                                    .buttonStyle(.plain)

                                    NavigationLink(value: TransferRoute.upcoming) {
                                        ManageRow(icon: "calendar", title: "Upcoming transfers")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Theme.card, in: .rect(cornerRadius: 12))
                            }
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

    /// Vertical results list shown when the user is typing in the search field.
    @ViewBuilder
    private var searchResults: some View {
        let matches = filteredBeneficiaries
        if matches.isEmpty {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 60, height: 60)
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.top, 16)

                Text("No matches for \u{201C}\(query)\u{201D}")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("Add a new beneficiary to send to someone you haven't paid before.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button {
                    showingBeneficiarySheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New beneficiary")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentDeep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 16))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Results")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(matches.count)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.15), in: .capsule)
                    Spacer()
                }

                VStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { idx, b in
                        NavigationLink(value: TransferRoute.detail(b)) {
                            SearchResultRow(
                                beneficiary: b,
                                showDivider: idx < matches.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Theme.card, in: .rect(cornerRadius: 16))
            }
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
                    .foregroundStyle(Theme.textSecondary)
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
                        .foregroundStyle(Theme.textPrimary)
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
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}

// MARK: - Search result row.
private struct SearchResultRow: View {
    let beneficiary: Beneficiary
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(beneficiary.avatarBg)
                    Text(beneficiary.initial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(beneficiary.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(beneficiary.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Rail badge.
                Text(railLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.cardOverlay, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.strokeSubtle, lineWidth: 1))

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)

            if showDivider {
                Rectangle()
                    .fill(Theme.cardOverlay)
                    .frame(height: 1)
                    .padding(.leading, 66)
            }
        }
    }

    private var railLabel: String {
        switch beneficiary.kind {
        case .wallet:        return "WALLET"
        case .uae:           return "UAE"
        case .international: return "INT'L"
        }
    }
}
