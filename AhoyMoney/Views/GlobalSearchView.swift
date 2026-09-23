import SwiftUI

/// Home-screen global search.
///
/// Research-informed (Revolut, Wise, Cash App, Monzo, N26): every fintech
/// global search shares this skeleton —
///
/// 1. **Empty state** — recent searches (chips) + quick actions + trending tags
/// 2. **Live results** — categorized sections: People, Cards, Scheduled,
///    Activity, Help, Quick actions; each row routes to the proper detail
/// 3. **No results** — friendly empty state with "Contact support" escape hatch
///
/// Auto-focuses the input on appear and records the term in
/// `GlobalSearchStore` whenever the user submits or taps a result.
struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GlobalSearchStore.self) private var searchStore
    @Environment(BeneficiaryStore.self) private var beneficiaries
    @Environment(VirtualCardStore.self) private var cards
    @Environment(UpcomingTransferStore.self) private var upcoming
    @Environment(HelpStore.self) private var help
    @Environment(TransactionStore.self) private var transactions
    @Environment(AppRouter.self) private var router

    @State private var query: String = ""
    @State private var pushedBeneficiary: Beneficiary? = nil
    @State private var pushedCardId: UUID? = nil
    @State private var pushedTransferId: UUID? = nil
    @State private var pushedArticleId: UUID? = nil
    @State private var goToTopUp: Bool = false
    @State private var goToScheduleTransfer: Bool = false
    @State private var goToCardsList: Bool = false
    @State private var goToBeneficiaries: Bool = false
    @State private var goToHelp: Bool = false
    @State private var goToUpcoming: Bool = false
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                searchHeader

                if trimmedQuery.isEmpty {
                    emptyState
                } else if hasAnyResults {
                    resultsList
                } else {
                    noResultsState
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $pushedBeneficiary) { b in
            BeneficiaryDetailView(beneficiary: b)
        }
        .navigationDestination(item: $pushedCardId) { id in
            CardDetailView(cardId: id)
        }
        .navigationDestination(item: $pushedTransferId) { id in
            UpcomingTransferDetailView(transferId: id)
        }
        .navigationDestination(item: $pushedArticleId) { id in
            HelpArticleView(articleId: id)
        }
        .navigationDestination(isPresented: $goToCardsList) { CardsListView() }
        .navigationDestination(isPresented: $goToBeneficiaries) { BeneficiariesListView() }
        .navigationDestination(isPresented: $goToHelp) { HelpCenterView() }
        .navigationDestination(isPresented: $goToUpcoming) { UpcomingTransfersView() }
        .navigationDestination(isPresented: $goToScheduleTransfer) { ScheduleTransferView() }
        .sheet(isPresented: $goToTopUp) { TopUpView().presentationDragIndicator(.hidden) }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { searchFocused = true }
        }
        .onSubmit(of: .search) { searchStore.record(trimmedQuery) }
    }

    // MARK: - Header

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(.white)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                TextField(
                    "",
                    text: $query,
                    prompt: Text("Search anything…").foregroundStyle(Theme.textSecondary)
                )
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { searchStore.record(trimmedQuery) }
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .tint(.white)

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
        }
        .padding(.horizontal, 19)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !searchStore.recentSearches.isEmpty {
                    section(title: "Recent searches", icon: "clock") {
                        VStack(spacing: 0) {
                            ForEach(Array(searchStore.recentSearches.enumerated()), id: \.offset) { idx, term in
                                Button {
                                    query = term
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.textSecondary)
                                        Text(term)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if idx < searchStore.recentSearches.count - 1 {
                                    Rectangle()
                                        .fill(Theme.cardOverlay)
                                        .frame(height: 1)
                                        .padding(.leading, 38)
                                }
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))

                        Button("Clear recents") {
                            searchStore.clearRecents()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 6)
                        .padding(.leading, 4)
                    }
                }

                section(title: "Quick actions", icon: "bolt.fill") {
                    quickActionsGrid
                }

                section(title: "Trending", icon: "flame.fill") {
                    trendingChips
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
    }

    private var quickActionsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            QuickActionTile(
                icon: "plus",
                title: "Top up",
                subtitle: "Add funds to your wallet",
                tint: Theme.accent
            ) { goToTopUp = true }

            QuickActionTile(
                icon: "calendar.badge.clock",
                title: "Schedule transfer",
                subtitle: "Set up recurring payment",
                tint: Color(red: 0.62, green: 0.40, blue: 1.00)
            ) { goToScheduleTransfer = true }

            QuickActionTile(
                icon: "creditcard.fill",
                title: "My cards",
                subtitle: "Browse virtual cards",
                tint: Color(red: 1.00, green: 0.55, blue: 0.45)
            ) { goToCardsList = true }

            QuickActionTile(
                icon: "person.2.fill",
                title: "Beneficiaries",
                subtitle: "People you've sent to",
                tint: Color(red: 0.20, green: 0.85, blue: 0.65)
            ) { goToBeneficiaries = true }
        }
    }

    private var trendingChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(searchStore.trending, id: \.self) { term in
                    Button { query = term } label: {
                        Text(term)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.cardOverlay, in: .capsule)
                            .overlay(Capsule().strokeBorder(Theme.strokeSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Live results

    /// Pre-filtered result groups — keeps the body readable.
    private var beneficiaryResults: [Beneficiary] {
        let q = trimmedQuery.lowercased()
        return beneficiaries.items.filter {
            $0.name.lowercased().contains(q)
            || ($0.nickname?.lowercased().contains(q) ?? false)
            || $0.subtitle.lowercased().contains(q)
            || ($0.phone?.contains(q) ?? false)
            || ($0.email?.lowercased().contains(q) ?? false)
        }
    }

    private var cardResults: [VirtualCard] {
        let q = trimmedQuery.lowercased()
        return cards.cards.filter {
            $0.label.lowercased().contains(q)
            || $0.last4.contains(q)
            || $0.cardholderName.lowercased().contains(q)
        }
    }

    private var upcomingResults: [UpcomingTransfer] {
        let q = trimmedQuery.lowercased()
        return upcoming.items.filter { t in
            // Match on note, amount text, currency, frequency, and recipient.
            if let note = t.note, note.lowercased().contains(q) { return true }
            if t.currency.lowercased().contains(q) { return true }
            if t.frequency.displayName.lowercased().contains(q) { return true }
            if "\(t.amount)".contains(q) { return true }
            if let b = beneficiaries.items.first(where: { $0.id == t.beneficiaryId }),
               b.displayName.lowercased().contains(q) { return true }
            return false
        }
    }

    private var transactionResults: [MockTransaction] {
        transactions.search(trimmedQuery)
    }

    private var helpResults: [HelpArticle] {
        help.search(trimmedQuery)
    }

    /// Quick "verb" matches — Cash App / Revolut style.
    /// "send", "top up", "schedule", "freeze", "help" — phrase shortcuts.
    private var actionMatches: [QuickAction] {
        let q = trimmedQuery.lowercased()
        var out: [QuickAction] = []
        if "top up".contains(q) || "add funds".contains(q) || q.starts(with: "to") {
            out.append(.init(icon: "plus", title: "Top up wallet", subtitle: "Add funds instantly", tint: Theme.accent, action: { goToTopUp = true }))
        }
        if "send".contains(q) || "transfer".contains(q) {
            out.append(.init(icon: "arrow.up.right", title: "Send money", subtitle: "Open the Send tab", tint: Theme.accent, action: { router.selectedTab = .send }))
        }
        if "schedule".contains(q) || "recurring".contains(q) {
            out.append(.init(icon: "calendar.badge.clock", title: "Schedule a transfer", subtitle: "Recurring or one-time", tint: Color(red: 0.62, green: 0.40, blue: 1.00), action: { goToScheduleTransfer = true }))
        }
        if "upcoming".contains(q) || "scheduled".contains(q) {
            out.append(.init(icon: "calendar", title: "Upcoming transfers", subtitle: "All your schedules", tint: Theme.accent, action: { goToUpcoming = true }))
        }
        if "card".contains(q) {
            out.append(.init(icon: "creditcard.fill", title: "All cards", subtitle: "Browse virtual cards", tint: Color(red: 1.00, green: 0.55, blue: 0.45), action: { goToCardsList = true }))
        }
        if "help".contains(q) || "support".contains(q) {
            out.append(.init(icon: "questionmark.circle.fill", title: "Open Help Center", subtitle: "Articles & contact", tint: Theme.accent, action: { goToHelp = true }))
        }
        return out
    }

    private var hasAnyResults: Bool {
        !beneficiaryResults.isEmpty
            || !cardResults.isEmpty
            || !upcomingResults.isEmpty
            || !transactionResults.isEmpty
            || !helpResults.isEmpty
            || !actionMatches.isEmpty
    }

    private var resultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !actionMatches.isEmpty {
                    section(title: "Actions", icon: "bolt.fill") {
                        VStack(spacing: 0) {
                            ForEach(Array(actionMatches.enumerated()), id: \.offset) { idx, action in
                                Button {
                                    searchStore.record(trimmedQuery)
                                    action.action()
                                } label: {
                                    SearchRow(
                                        icon: action.icon,
                                        tint: action.tint,
                                        title: action.title,
                                        subtitle: action.subtitle,
                                        showDivider: idx < actionMatches.count - 1
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                }

                if !beneficiaryResults.isEmpty {
                    section(
                        title: "People",
                        icon: "person.2.fill",
                        seeAll: beneficiaryResults.count > 3
                            ? { goToBeneficiaries = true } : nil
                    ) {
                        VStack(spacing: 0) {
                            ForEach(Array(beneficiaryResults.prefix(3).enumerated()), id: \.element.id) { idx, b in
                                Button {
                                    searchStore.record(trimmedQuery)
                                    pushedBeneficiary = b
                                } label: {
                                    SearchRow(
                                        avatar: AvatarBadge(bg: b.avatarBg, initial: b.initial),
                                        title: highlight(b.displayName),
                                        subtitle: b.subtitle,
                                        showDivider: idx < min(beneficiaryResults.count, 3) - 1
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                }

                if !cardResults.isEmpty {
                    section(
                        title: "Cards",
                        icon: "creditcard.fill",
                        seeAll: cardResults.count > 3 ? { goToCardsList = true } : nil
                    ) {
                        VStack(spacing: 0) {
                            ForEach(Array(cardResults.prefix(3).enumerated()), id: \.element.id) { idx, c in
                                Button {
                                    searchStore.record(trimmedQuery)
                                    pushedCardId = c.id
                                } label: {
                                    SearchRow(
                                        icon: "creditcard.fill",
                                        tint: Color(red: 1.00, green: 0.55, blue: 0.45),
                                        title: highlight(c.label),
                                        subtitle: "•••• \(c.last4) · \(c.cardholderName)",
                                        showDivider: idx < min(cardResults.count, 3) - 1
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                }

                if !upcomingResults.isEmpty {
                    section(
                        title: "Scheduled",
                        icon: "calendar.badge.clock",
                        seeAll: upcomingResults.count > 3 ? { goToUpcoming = true } : nil
                    ) {
                        VStack(spacing: 0) {
                            ForEach(Array(upcomingResults.prefix(3).enumerated()), id: \.element.id) { idx, t in
                                Button {
                                    searchStore.record(trimmedQuery)
                                    pushedTransferId = t.id
                                } label: {
                                    SearchRow(
                                        icon: t.frequency.icon,
                                        tint: Theme.accent,
                                        title: "\(t.currency) \(UpcomingTransfer.format(t.amount))",
                                        subtitle: subtitleForUpcoming(t),
                                        showDivider: idx < min(upcomingResults.count, 3) - 1
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                }

                if !transactionResults.isEmpty {
                    section(title: "Activity", icon: "rectangle.stack.fill") {
                        VStack(spacing: 0) {
                            ForEach(Array(transactionResults.prefix(5).enumerated()), id: \.element.id) { idx, t in
                                Button {
                                    searchStore.record(trimmedQuery)
                                    router.selectedTab = .transactions
                                } label: {
                                    SearchRow(
                                        icon: t.icon,
                                        tint: t.isCredit ? Color(red: 0.34, green: 0.85, blue: 0.55) : Theme.accent,
                                        title: highlight(t.title),
                                        subtitle: "\(t.merchant) · \(MockTransaction.dateFormatter.string(from: t.date))",
                                        trailing: amountText(t),
                                        showDivider: idx < min(transactionResults.count, 5) - 1
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                }

                if !helpResults.isEmpty {
                    section(
                        title: "Help",
                        icon: "questionmark.circle.fill",
                        seeAll: helpResults.count > 3 ? { goToHelp = true } : nil
                    ) {
                        VStack(spacing: 0) {
                            ForEach(Array(helpResults.prefix(3).enumerated()), id: \.element.id) { idx, h in
                                Button {
                                    searchStore.record(trimmedQuery)
                                    pushedArticleId = h.id
                                } label: {
                                    SearchRow(
                                        icon: h.category.icon,
                                        tint: h.category.tint,
                                        title: highlight(h.question),
                                        subtitle: h.category.displayName,
                                        showDivider: idx < min(helpResults.count, 3) - 1
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - No results

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Spacer()

            EmptyStateArt(name: "empty_search", size: 112)

            Text("Nothing matches \u{201C}\(trimmedQuery)\u{201D}")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("Try a different keyword, or contact support if you're stuck.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button {
                goToHelp = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Open Help Center")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.accent, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func subtitleForUpcoming(_ t: UpcomingTransfer) -> String {
        let recipient = beneficiaries.items.first { $0.id == t.beneficiaryId }?.displayName
        let next = t.nextRelative
        if let r = recipient {
            return "\(t.frequency.shortName) · to \(r) · \(next)"
        }
        return "\(t.frequency.shortName) · \(next)"
    }

    private func highlight(_ text: String) -> AttributedString {
        var s = AttributedString(text)
        let q = trimmedQuery
        guard !q.isEmpty,
              let range = s.range(of: q, options: [.caseInsensitive, .diacriticInsensitive])
        else { return s }
        s[range].foregroundColor = Theme.accent
        s[range].font = .system(size: 14, weight: .heavy)
        return s
    }

    private func amountText(_ t: MockTransaction) -> some View {
        Text("\(t.isCredit ? "+" : "−")AED \(UpcomingTransfer.format(t.amount))")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(t.isCredit ? Color(red: 0.34, green: 0.85, blue: 0.55) : .white)
            .monospacedDigit()
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        icon: String,
        seeAll: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let seeAll {
                    Button(action: seeAll) {
                        Text("See all")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            content()
        }
    }
}

// MARK: - Quick action

private struct QuickAction {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void
}

// MARK: - Quick action tile

private struct QuickActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.18))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.cardOverlay, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar badge

private struct AvatarBadge: View {
    let bg: Color
    let initial: String
    var body: some View {
        ZStack {
            Circle().fill(bg)
            Text(initial)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Search row (icon-or-avatar + title + subtitle + optional trailing)

private struct SearchRow<Trailing: View>: View {
    var icon: String? = nil
    var tint: Color = Theme.accent
    var avatar: AvatarBadge? = nil
    let title: AttributedString
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing
    let showDivider: Bool

    init(
        icon: String? = nil,
        tint: Color = Theme.accent,
        avatar: AvatarBadge? = nil,
        title: AttributedString,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        showDivider: Bool
    ) {
        self.icon = icon
        self.tint = tint
        self.avatar = avatar
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.showDivider = showDivider
    }

    /// Convenience init for plain string titles.
    init(
        icon: String? = nil,
        tint: Color = Theme.accent,
        avatar: AvatarBadge? = nil,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        showDivider: Bool
    ) {
        self.init(
            icon: icon, tint: tint, avatar: avatar,
            title: AttributedString(title), subtitle: subtitle,
            trailing: trailing, showDivider: showDivider
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let avatar {
                    avatar
                } else if let icon {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(0.18))
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                trailing()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Rectangle()
                    .fill(Theme.cardOverlay)
                    .frame(height: 1)
                    .padding(.leading, 62)
            }
        }
    }
}

// Trailing-less convenience init.
extension SearchRow where Trailing == AnyView {
    init(
        icon: String? = nil,
        tint: Color = Theme.accent,
        avatar: AvatarBadge? = nil,
        title: AttributedString,
        subtitle: String,
        trailing: some View,
        showDivider: Bool
    ) {
        self.init(
            icon: icon, tint: tint, avatar: avatar,
            title: title, subtitle: subtitle,
            trailing: { AnyView(trailing) },
            showDivider: showDivider
        )
    }
}
