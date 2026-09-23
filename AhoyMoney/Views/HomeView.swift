import SwiftUI

struct HomeView: View {
    @Environment(WalletStore.self) private var wallet
    @Environment(VirtualCardStore.self) private var cards
    @Environment(AppRouter.self) private var router
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(TransactionStore.self) private var activity

    @State private var query: String = ""
    @State private var showTopUp: Bool = false
    @State private var showCardTerms: Bool = false
    @State private var goToCreateCard: Bool = false
    @State private var goToCardsList: Bool = false
    @State private var pushedCardId: UUID? = nil
    @State private var showVerifyEmail: Bool = false
    @State private var goToSearch: Bool = false
    /// Which carousel item is in front. A string rather than a `UUID` because
    /// the All-cards tile is an item too, and it has no card behind it.
    @State private var heroItemId: String?

    // MARK: - Hero carousel metrics

    /// Item width as a fraction of the carousel's *content* width — which is
    /// the screen less both `heroMargin`s, because `contentMargins` insets the
    /// container `containerRelativeFrame` measures against. 19/20 of 358 is
    /// 340pt, leaving a 28pt sliver of the next card past the 12pt gap.
    ///
    /// Measured at 17/20 first: that gave a 304pt card and a 64pt peek, which
    /// read clearly but shrank the hero more than the peek was worth.
    private static let heroSpan = 19
    private static let heroSpanTotal = 20
    private static let heroMargin: CGFloat = 22
    private static let heroGap: CGFloat = 12
    private static let allCardsItemId = "all-cards"
    @State private var goToChecklist: Bool = false
    @State private var goToAccountState: Bool = false

    /// The worker's own cards, swipeable — the same gesture as My Cards and the
    /// card screen, so one card behaves the same way everywhere it appears.
    ///
    /// Tapping a card opens that card, not the list: the worker is already
    /// looking at the one they want.
    ///
    /// **The next card peeks in from the trailing edge**, and that peek is the
    /// whole point. The previous version was a full-width paged `TabView`, so a
    /// worker with three cards saw exactly what a worker with one card saw —
    /// the only difference was a 5pt dot row sitting where the Wallet Balance
    /// panel overlaps it. A text link ("My cards · 2 of 3") was carrying the
    /// job the cards should carry themselves, which is why it's gone.
    ///
    /// Starling, Wise, Chime, Vivid and Starbucks all do this; the sliver of a
    /// second card is self-evident in a way a label never is.
    private var issuedCardStack: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Self.heroGap) {
                ForEach(cards.cards) { card in
                    Button {
                        pushedCardId = card.id
                    } label: {
                        heroCardArt(card)
                    }
                    .buttonStyle(.plain)
                    .id(card.id.uuidString)
                }

                // Swiping right is how you explore a carousel, so the route to
                // the section is where that gesture already ends up rather than
                // somewhere else on the screen. Klarna puts "Create new card"
                // in the same place.
                allCardsTile
                    .id(Self.allCardsItemId)
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        // The peek has to survive the ScrollView's own clipping.
        .scrollClipDisabled()
        .contentMargins(.horizontal, Self.heroMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $heroItemId, anchor: .leading)
        // `scrollPosition` only reports once something scrolls, so on a cold
        // open every capsule sat inactive. Seed it from the first card, and
        // re-seed if the carousel changes under it.
        .onAppear { seedHeroItem() }
        .onChange(of: cards.cards.map(\.id)) { _, _ in seedHeroItem() }
    }

    private func seedHeroItem() {
        let ids = cards.cards.map(\.id.uuidString) + [Self.allCardsItemId]
        if heroItemId == nil || !ids.contains(heroItemId!) {
            heroItemId = ids.first
        }
    }

    /// One card at the carousel's item width, holding the artwork's aspect.
    private func heroCardArt(_ card: VirtualCard) -> some View {
        Color.clear
            .aspectRatio(340.0 / 212.0, contentMode: .fit)
            .containerRelativeFrame(
                .horizontal,
                count: Self.heroSpanTotal,
                span: Self.heroSpan,
                spacing: 0
            )
            .overlay {
                GeometryReader { geo in
                    CardArtwork(card: card, size: geo.size)
                }
            }
    }

    /// The last item in the carousel: the route into My Cards, and the only
    /// place on Home that says how many cards there are.
    ///
    /// Dashed and card-shaped, so it reads as "the rest of them live here"
    /// rather than as another card. Same treatment as `emptyCardSlot`, where
    /// dashed already means a slot rather than a thing.
    private var allCardsTile: some View {
        Button {
            goToCardsList = true
        } label: {
            Color.clear
                .aspectRatio(340.0 / 212.0, contentMode: .fit)
                .containerRelativeFrame(
                    .horizontal,
                    count: Self.heroSpanTotal,
                    span: Self.heroSpan,
                    spacing: 0
                )
                .overlay {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.14))
                                .frame(width: 48, height: 48)
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }

                        VStack(spacing: 3) {
                            Text("All cards")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            // The count lives here and nowhere else. Said once,
                            // next to the thing it counts.
                            Text("\(cards.cards.count) of \(cards.maxCards)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }

                        // Only offered while there's a slot to fill. At the cap
                        // this would be a button that can't do what it says —
                        // the live `+` on My Cards is what explains the limit.
                        if cards.canCreateCard {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                Text("New card")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Theme.accentDeep)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.accent, in: .capsule)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.cardOverlay)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    Theme.strokeSubtle,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All cards. \(cards.cards.count) of \(cards.maxCards).")
    }

    /// One capsule per card, plus one for the All-cards tile, so the row also
    /// says that swiping past the last card leads somewhere.
    ///
    /// Sits *below* the carousel, centred. Overlaid on the artwork it was
    /// unreadable against a light design; leading-aligned it read as a stray
    /// row rather than as the carousel's own position marker.
    private var heroIndicator: some View {
        let ids = cards.cards.map(\.id.uuidString) + [Self.allCardsItemId]
        return HStack(spacing: 6) {
            ForEach(ids, id: \.self) { id in
                let active = id == heroItemId
                Capsule()
                    .fill(active ? Theme.accent : Color.white.opacity(0.3))
                    .frame(width: active ? 16 : 6, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: heroItemId)
        .padding(.horizontal, Self.heroMargin)
        // The enclosing VStack's 12pt spacing is the gap; nothing extra here.
    }

    /// The card-shaped empty slot.
    ///
    /// Borrowed from Klarna: the placeholder occupies the *exact* footprint a
    /// real card will — same aspect ratio, same corner radius — so it reads as
    /// "your card goes here" rather than as a missing feature, and the layout
    /// doesn't jump the moment one is created.
    ///
    /// Dashed, matching the arrival screen, where dashed already means an empty
    /// slot you can fill. The whole slot is the button; a small "Create" link
    /// inside a card-sized target would waste the affordance.
    private var emptyCardSlot: some View {
        Button {
            showCardTerms = true
        } label: {
            Color.clear
                .aspectRatio(340.0 / 212.0, contentMode: .fit)
                .overlay {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.14))
                                .frame(width: 54, height: 54)
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }

                        VStack(spacing: 4) {
                            Text("No card yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Make one and you can spend straight away")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.cardOverlay)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    Theme.strokeSubtle,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No card yet. Create a card.")
    }

    /// The review, shown as a state rather than a countdown.
    ///
    /// Not an alert: an alert is modal, has to be dismissed, and would fire on
    /// every launch for a day. The review isn't news, it's a state, and states
    /// belong in the layout rather than on top of it.
    ///
    /// No progress bar either. The window is working days, not wall-clock
    /// hours, so a bar fills at the wrong rate — and once full it reads as
    /// overdue for exactly the people whose file is taking longest.
    private func reviewProgressBanner(since: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("We're checking your details")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
                Text(UnderReviewView.relative.localizedString(for: since, relativeTo: Date()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text("Your wallet opens as soon as this is done. Have a look around meanwhile.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                )
        )
        .contentShape(.rect)
    }

    /// Nothing has happened yet.
    ///
    /// Deliberately quiet: no illustration and no button. An empty history is
    /// the normal state of a new account, not a problem, and a second call to
    /// action here would compete with the card slot directly above it.
    private var emptyActivity: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 2)
            Text("Nothing here yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Money you add, send or spend will show up here.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
    }

    /// The card slot while the wallet is still shut.
    ///
    /// Same footprint as the real card and the empty slot, so the layout holds
    /// still through every state. It explains instead of inviting: telling
    /// someone under review to "create a card" and then refusing is worse than
    /// saying up front that it isn't available yet. This is what makes "look
    /// around while you wait" an honest offer rather than a maze of dead ends.
    private var lockedCardSlot: some View {
        Color.clear
            .aspectRatio(340.0 / 212.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "lock")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)

                    VStack(spacing: 4) {
                        Text("Your card comes later")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("You can make one as soon as your details are checked.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 28)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.strokeSubtle.opacity(0.6), lineWidth: 1)
                    )
            )
    }

    /// Account status, shown above the card hero.
    ///
    /// Driven by `displayState` rather than a single Bool. That Bool made
    /// "not verified" and "under review" the same thing, so the screen could
    /// claim a file was being reviewed while the customer still owed us two
    /// documents — states the model says can't coexist.
    ///
    /// The approved case is deliberately empty pending the card gate: what an
    /// approved customer sees here depends on whether the card is locked until
    /// approval, which isn't settled.
    @ViewBuilder
    private var accountStatusBlock: some View {
        switch onboarding.displayState {
        case .registered:
            EmptyView()

        case let .identityFailed(_, canRetry):
            Button { goToAccountState = true } label: {
                statusPill(
                    icon: "person.crop.circle.badge.exclamationmark",
                    text: canRetry ? "We couldn't read your ID" : "We're looking at your ID",
                    tint: Theme.warning
                )
            }
            .buttonStyle(.plain)

        case .profileIncomplete:
            // The real checklist, both items — not just email. Finishing one
            // and still not being submitted is the confusing part, so the count
            // is on the label.
            Button {
                goToChecklist = true
            } label: {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "checklist")
                            .font(.system(size: 14, weight: .semibold))
                        // "Optional" was doing two jobs: telling them it isn't
                        // required, and naming the thing. The subtitle already
                        // carries the first, so the label just names the task.
                        Text("Complete your profile")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .capsule)

                }
            }
            .buttonStyle(.plain)

        case let .underReview(since, _, request):
            // An open request is not a separate status — it's something inside
            // the review, so this says which it is without demoting one.
            Button { goToAccountState = true } label: {
                if let request {
                    statusPill(
                        icon: "tray.and.arrow.up",
                        text: "We need one more thing from you",
                        tint: Theme.warning
                    )
                    .accessibilityHint("\(request.items.count) document requested")
                } else {
                    reviewProgressBanner(since: since)
                }
            }
            .buttonStyle(.plain)

        case .systemRefused:
            Button { goToAccountState = true } label: {
                statusPill(
                    icon: "exclamationmark.octagon",
                    text: "We cannot continue right now",
                    tint: Theme.warning
                )
            }
            .buttonStyle(.plain)

        case .rejected:
            Button { goToAccountState = true } label: {
                statusPill(
                    icon: "xmark.circle",
                    text: "We can't open an account for you",
                    tint: Color(red: 1.0, green: 0.42, blue: 0.42)
                )
            }
            .buttonStyle(.plain)

        case .approved:
            // Active — the common landing, and the one with nothing to say.
            //
            // There used to be a "Make a virtual card" pill here. The empty
            // card slot below now carries that job and carries it better: it's
            // card-shaped, card-sized, and sits where the card will be. Two
            // buttons for one action just made the customer choose between
            // identical doors.
            EmptyView()
        }
    }

    @ViewBuilder
    private var accountStateDestination: some View {
        switch onboarding.displayState {
        case let .identityFailed(attemptsUsed, canRetry):
            IdentityFailedView(attemptsUsed: attemptsUsed, canRetry: canRetry)
        case let .underReview(since, reason, request):
            if let request {
                // Supplying it clears the request; the file stays under review
                // with the same reviewer, rather than starting again.
                MoreInfoNeededView(request: request) {
                    onboarding.complianceDecision = .underReview(since: since, reason: reason, request: nil)
                    goToAccountState = false
                }
            } else {
                UnderReviewView(since: since, reason: reason)
            }
        case let .systemRefused(retryFrom):
            SystemRefusedView(retryFrom: retryFrom, onRetry: { goToAccountState = false })
        case let .rejected(reapplyFrom):
            RejectedView(reapplyFrom: reapplyFrom)
        default:
            EmptyView()
        }
    }

    private func statusPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: .capsule)
    }

    var body: some View {
        NavigationStack {
            content
                // Picks up "Create your card" from the arrival screen. Done on
                // landing rather than mid-onboarding so the customer sees their
                // wallet exists before the card flow opens over it.
                .onAppear {
                    guard router.pendingCardCreation else { return }
                    router.pendingCardCreation = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        showCardTerms = true
                    }
                }
                .sheet(isPresented: $showCardTerms) {
                    CardTermsSheet(onAccepted: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            goToCreateCard = true
                        }
                    })
                }
                .navigationDestination(isPresented: $goToCreateCard) {
                    CreateCardView()
                }
                .navigationDestination(isPresented: $goToCardsList) {
                    CardsListView()
                }
                .navigationDestination(item: $pushedCardId) { id in
                    CardDetailView(cardId: id)
                }
                .navigationDestination(isPresented: $goToSearch) {
                    GlobalSearchView()
                }
                .navigationDestination(isPresented: $goToChecklist) {
                    ProfileChecklistView()
                }
                // The four states that have a screen behind them. Without this
                // they were built but unreachable, which fails "a linked
                // prototype walks the full journey".
                .navigationDestination(isPresented: $goToAccountState) {
                    accountStateDestination
                }
        }
    }

    private var content: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Avatar + glass search bar.
                    HStack(spacing: 12) {
                        Image("settings_avatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .background(Color(red: 1, green: 0.86, blue: 0.87))
                            .clipShape(Circle())

                        // Tap to open the global search.
                        Button {
                            goToSearch = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Theme.textSecondary)
                                Text("Search anything…")
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer(minLength: 0)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .font(.system(size: 17))
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                    // The "My cards · N of 3" link that used to sit here is
                    // gone. It was a nav label doing a status job: it named a
                    // count the cards themselves should show, and it leaked our
                    // cap before anyone had asked for a second card. Both now
                    // live on the All-cards tile at the end of the carousel.

                    // Card hero with gradient fade + Get Virtual Card pill.
                    //
                    // The account-status block sits *above* the hero rather than
                    // on top of it: it's a notice about the worker's
                    // application, not about any card, and overlaying it covered
                    // the card's own label and number.
                    VStack(spacing: 12) {
                        accountStatusBlock
                            .padding(.horizontal, 22)

                        // Nothing is issued until a held file is decided, so
                        // the hero shows neither a wallet nor a card.
                        if !onboarding.walletOpen {
                            lockedCardSlot
                                .padding(.horizontal, 22)
                        } else if cards.cards.isEmpty {
                            emptyCardSlot
                                .padding(.horizontal, 22)
                        } else {
                            // Each card in the pager is its own button, so this
                            // can't be wrapped in an outer one.
                            issuedCardStack
                            heroIndicator
                        }
                    }
                    .padding(.bottom, 4)
                    // No fixed height. 333 was the empty-state illustration's
                    // height, and forcing it here centred the real card — which
                    // is width-driven and only ~223pt tall — inside a 333pt box,
                    // leaving ~55pt of dead space above it and the same below.
                    //
                    // The 22pt gutter moved onto the children: the carousel has
                    // to reach the screen edge for the next card to peek, and
                    // it sets its own margin through `contentMargins`.

                    // Wallet balance + Top Up + Recent activities.
                    VStack(spacing: 20) {
                        // Wallet balance + Top Up.
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Wallet Balance")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                                Spacer(minLength: 0)
                                HStack(spacing: 6) {
                                    CurrencyIcon(size: 16)
                                    Text(WalletStore.formatMoney(wallet.balance))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                            .padding(12)
                            .frame(width: 176, height: 65, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))

                            Spacer()

                            VStack(spacing: 8) {
                                Button {
                                    showTopUp = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .padding(12)
                                        .glassEffect(.regular.interactive(), in: .circle)
                                }
                                .buttonStyle(.plain)

                                Text("Top Up")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }

                        // Recent activities.
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Activities")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                // Was plain text with no action. It's the only
                                // route to the account-level Transactions page
                                // that doesn't depend on the tab bar.
                                Button {
                                    router.selectedTab = .transactions
                                } label: {
                                    Text("View All")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(spacing: 16) {
                                // Driven by the store rather than six hard-coded
                                // rows, so a new account genuinely shows nothing.
                                if activity.items.isEmpty {
                                    emptyActivity
                                } else {
                                    ForEach(activity.items.prefix(6)) { item in
                                        ActivityRow(
                                            icon: item.icon,
                                            title: item.title,
                                            date: MockTransaction.dateFormatter.string(from: item.date).uppercased(),
                                            amount: WalletStore.formatMoney(item.amount)
                                        )
                                    }
                                }
                            }
                            .padding(12)
                            .background(Theme.card, in: .rect(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 60)
                }
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showTopUp) {
            TopUpView()
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showVerifyEmail) {
            VerifyEmailSheet(onVerify: {
                wallet.isAccountVerified = true
            })
        }
    }
}

private struct ActivityRow: View {
    var icon: String
    var title: String
    var date: String
    var amount: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0x03/255, green: 0x01/255, blue: 0x26/255))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(date)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                }
            }

            Spacer()

            HStack(spacing: 4) {
                CurrencyIcon(size: 14)
                Text(amount)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}

struct CurrencyIcon: View {
    var size: CGFloat = 16
    var color: Color = .white

    var body: some View {
        Image("currency_baht")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .foregroundStyle(color)
    }
}
