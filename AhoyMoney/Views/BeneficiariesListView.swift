import SwiftUI

/// Full directory of saved beneficiaries.
///
/// Layout:
/// • Top bar (back, title, "+" glass add button)
/// • Glass search capsule
/// • Horizontal filter chips: All, Wallet, UAE, International, ★
/// • Sectioned list: Favorites first, then "All" alphabetical
/// • Tap row → BeneficiaryDetailView
/// • Long-press row → context menu (Send, Edit, Pin, Delete)
/// • Empty state when nothing matches
struct BeneficiariesListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BeneficiaryStore.self) private var store

    @State private var query: String = ""
    @State private var filter: Filter = .all
    @State private var showAddSheet: Bool = false
    @State private var pendingKind: BeneficiaryKind? = nil

    enum Filter: Hashable {
        case all, wallet, uae, international, favorites

        var label: String {
            switch self {
            case .all:           return "All"
            case .wallet:        return "Wallet"
            case .uae:           return "UAE Bank"
            case .international: return "International"
            case .favorites:     return "★ Favorites"
            }
        }
    }

    // MARK: - Filtering

    private var filtered: [Beneficiary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.items.filter { b in
            // Type filter.
            switch filter {
            case .all:           break
            case .wallet:        if b.kind != .wallet { return false }
            case .uae:           if b.kind != .uae { return false }
            case .international: if b.kind != .international { return false }
            case .favorites:     if !b.isFavorite { return false }
            }
            // Text query.
            guard !q.isEmpty else { return true }
            let haystack = [
                b.name, b.nickname ?? "", b.subtitle, b.phone ?? "",
                b.email ?? "", b.bankName ?? "", b.iban ?? "",
                b.country ?? ""
            ].joined(separator: " ").lowercased()
            return haystack.contains(q)
        }
    }

    private var favorites: [Beneficiary] {
        filtered.filter(\.isFavorite)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var others: [Beneficiary] {
        filtered.filter { !$0.isFavorite }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - View

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                topBar
                searchAndFilters

                if filtered.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddSheet) {
            BeneficiaryTypeSheet(onSelect: { kind in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    pendingKind = kind
                }
            })
        }
        .navigationDestination(item: $pendingKind) { kind in
            AddBeneficiaryView(kind: kind)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Beneficiaries")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

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

                Button {
                    BiometricAuth.authenticate(reason: "Authenticate to add a new beneficiary") { success in
                        if success { showAddSheet = true }
                    }
                } label: {
                    Image(systemName: "plus")
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
    }

    // MARK: - Search + filters

    private var searchAndFilters: some View {
        VStack(spacing: 14) {
            // Search field — iOS 26 liquid glass.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))
                TextField(
                    "",
                    text: $query,
                    prompt: Text("Search by name, bank, IBAN…").foregroundStyle(.white.opacity(0.7))
                )
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .tint(.white)

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 17))
            .padding(.horizontal, 14)
            .frame(height: 44)
            .glassEffect(.regular.interactive(), in: .capsule)

            // Filter chips.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([Filter.all, .favorites, .wallet, .uae, .international], id: \.self) { f in
                        FilterChip(
                            label: f.label,
                            isActive: filter == f
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                filter = f
                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !favorites.isEmpty {
                    section(title: "Favorites", count: favorites.count, items: favorites)
                        .scrollEdgeBlur()
                }
                if !others.isEmpty {
                    section(title: "All beneficiaries", count: others.count, items: others)
                        .scrollEdgeBlur()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    @ViewBuilder
    private func section(title: String, count: Int, items: [Beneficiary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, b in
                    NavigationLink(value: BeneficiaryRoute.detail(b)) {
                        BeneficiaryRow(beneficiary: b, showDivider: idx < items.count - 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            // TODO: hook into a future "amount entry" flow.
                        } label: {
                            Label("Send Money", systemImage: "paperplane.fill")
                        }
                        Button {
                            store.toggleFavorite(b)
                        } label: {
                            Label(
                                b.isFavorite ? "Unpin from Favorites" : "Pin to Favorites",
                                systemImage: b.isFavorite ? "star.slash" : "star.fill"
                            )
                        }
                        Divider()
                        Button(role: .destructive) {
                            store.remove(b)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))
        }
        .navigationDestination(for: BeneficiaryRoute.self) { route in
            switch route {
            case .detail(let b): BeneficiaryDetailView(beneficiary: b)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: query.isEmpty ? "person.2.fill" : "magnifyingglass")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            Text(query.isEmpty ? "No beneficiaries yet" : "No matches found")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(query.isEmpty
                 ? "Add someone you send money to often — \nwe'll keep them one tap away."
                 : "Try a different search or filter.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if query.isEmpty {
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add your first beneficiary")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Routes

private enum BeneficiaryRoute: Hashable {
    case detail(Beneficiary)
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Theme.accentDeep : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive ? Theme.accent : Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isActive ? Color.clear : Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

struct BeneficiaryRow: View {
    let beneficiary: Beneficiary
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar.
                ZStack {
                    Circle().fill(beneficiary.avatarBg)
                    Text(beneficiary.initial)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 44, height: 44)

                // Name + subtitle.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(beneficiary.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if beneficiary.kind == .wallet {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }

                        if beneficiary.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    HStack(spacing: 6) {
                        KindPill(kind: beneficiary.kind)
                        Text(beneficiary.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())

            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 70)
            }
        }
    }
}

/// Tiny rail-type pill — visually similar to KindBadge in success view but smaller for list rows.
struct KindPill: View {
    let kind: BeneficiaryKind

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.accent.opacity(0.12), in: .capsule)
    }

    private var label: String {
        switch kind {
        case .wallet:        return "WALLET"
        case .uae:           return "UAE"
        case .international: return "INTL"
        }
    }
}
