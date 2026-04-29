import SwiftUI

/// The Help Center hub — entered from `SettingsView`.
///
/// Layout (top → bottom):
/// • Top bar with back + glass icon
/// • Hero: personalised greeting + global search field (tap → `HelpSearchView`)
/// • Service-status pill (cyan glass) — reduces anxiety before users ask
/// • Quick contact row: Chat / Call / Email — humans-first principle
/// • Popular questions — top 4, surfaced so users don't dig
/// • Browse-by-category 2-col grid with distinctive gradients
/// • Footer with version + legal touch
struct HelpCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HelpStore.self) private var store

    @State private var goToSearch: Bool = false
    @State private var pushedCategory: HelpCategory? = nil
    @State private var pushedArticleId: UUID? = nil
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 24) {
                    hero.scrollEdgeBlur()
                    statusPill.scrollEdgeBlur()
                    quickContact.scrollEdgeBlur()
                    popularSection.scrollEdgeBlur()
                    categoriesSection.scrollEdgeBlur()
                    footer.scrollEdgeBlur()
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .padding(.horizontal, 19)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goToSearch) {
            HelpSearchView()
        }
        .navigationDestination(item: $pushedCategory) { category in
            HelpCategoryView(category: category)
        }
        .navigationDestination(item: $pushedArticleId) { id in
            HelpArticleView(articleId: id)
        }
        .liquidGlassToast(
            isPresented: $showToast,
            message: toastMessage,
            duration: 1.8
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Help Center")
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

                // Direct line to support.
                Button {
                    toast("Live chat coming soon")
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hi Yousri 👋")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text("How can we help today?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            // Search trigger — looks like a search bar but routes to a
            // dedicated search screen. Keeps the home view fast.
            Button {
                goToSearch = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Search articles, topics, or questions")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    Spacer()

                    // Voice hint — nice touch, hooks up later.
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status pill

    private var statusPill: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.30, green: 0.85, blue: 0.55).opacity(0.25))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color(red: 0.30, green: 0.85, blue: 0.55))
                    .frame(width: 8, height: 8)
            }
            .overlay(
                Circle()
                    .stroke(Color(red: 0.30, green: 0.85, blue: 0.55).opacity(0.4), lineWidth: 1)
                    .scaleEffect(1.5)
                    .opacity(0.6)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("All services running normally")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Last checked just now")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.85, blue: 0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06), in: .capsule)
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Quick contact

    private var quickContact: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Talk to a human")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                ContactTile(
                    icon: "bubble.left.fill",
                    title: "Chat",
                    subtitle: "24/7 • Avg 2 min",
                    accent: Theme.accent
                ) {
                    toast("Live chat coming soon")
                }

                ContactTile(
                    icon: "phone.fill",
                    title: "Call",
                    subtitle: "Mon–Sun 8am–10pm",
                    accent: Color(red: 0.34, green: 0.85, blue: 0.55)
                ) {
                    if let url = URL(string: "tel:+97180024699") {
                        UIApplication.shared.open(url)
                    }
                }

                ContactTile(
                    icon: "envelope.fill",
                    title: "Email",
                    subtitle: "Reply in 24h",
                    accent: Color(red: 1.00, green: 0.79, blue: 0.30)
                ) {
                    if let url = URL(string: "mailto:help@ahoy.ae") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    // MARK: - Popular

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("Popular questions")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            VStack(spacing: 0) {
                let popular = store.popular()
                ForEach(Array(popular.enumerated()), id: \.element.id) { idx, article in
                    Button {
                        pushedArticleId = article.id
                    } label: {
                        PopularRow(
                            number: idx + 1,
                            article: article,
                            showDivider: idx < popular.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Browse by topic")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(HelpCategory.allCases.count) topics")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(HelpCategory.allCases) { category in
                    Button {
                        pushedCategory = category
                    } label: {
                        CategoryTile(
                            category: category,
                            articleCount: store.articles(in: category).count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Can't find an answer?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("Our team is one tap away — average response under 2 minutes.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                toast("Live chat coming soon")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Contact support")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Text("Ahoy v1.0.0  •  Regulated by UAE Central Bank")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showToast = true }
    }
}

// MARK: - Contact tile

private struct ContactTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.card, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Popular row

private struct PopularRow: View {
    let number: Int
    let article: HelpArticle
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Numbered chip — adds a sense of "top 4" leaderboard.
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                    Text("\(number)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Image(systemName: article.category.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(article.category.displayName)
                            .font(.system(size: 10, weight: .semibold))
                        if let mins = article.readTime {
                            Text("•")
                            Text("\(mins) min read")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundStyle(article.category.tint)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 52)
            }
        }
    }
}

// MARK: - Category tile

private struct CategoryTile: View {
    let category: HelpCategory
    let articleCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Big icon with the category gradient as a backdrop.
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(category.gradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RadialGradient(
                            colors: [Color.white.opacity(0.3), .clear],
                            center: UnitPoint(x: 0.2, y: 0.0),
                            startRadius: 4, endRadius: 36
                        )
                        .blendMode(.plusLighter)
                    )

                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(category.tagline)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                Text("\(articleCount)")
                    .font(.system(size: 11, weight: .heavy))
                Text(articleCount == 1 ? "article" : "articles")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(category.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(category.tint.opacity(0.12), in: .capsule)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(category.tint.opacity(0.10), lineWidth: 1)
        )
    }
}
