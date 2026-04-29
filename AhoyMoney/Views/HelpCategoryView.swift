import SwiftUI

/// All articles within a single category, with a persistent search input
/// that filters within-category as the user types.
///
/// Layout:
/// • Top bar (back, glass icon, search shortcut)
/// • Category hero — gradient block with icon + title + tagline + count
/// • Search field (filters within this category only)
/// • List of articles (Q + read time + chevron)
struct HelpCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HelpStore.self) private var store

    let category: HelpCategory

    @State private var query: String = ""
    @State private var pushedArticleId: UUID? = nil
    @FocusState private var searchFocused: Bool

    private var filteredArticles: [HelpArticle] {
        let all = store.articles(in: category)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.question.lowercased().contains(q)
            || $0.answer.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero.scrollEdgeBlur()
                    searchField.scrollEdgeBlur()
                    articleList.scrollEdgeBlur()
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
        .navigationDestination(item: $pushedArticleId) { id in
            HelpArticleView(articleId: id)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text(category.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 70)

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

                Color.clear.frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(category.gradient)
                    .frame(width: 64, height: 64)
                    .overlay(
                        RadialGradient(
                            colors: [Color.white.opacity(0.3), .clear],
                            center: UnitPoint(x: 0.2, y: 0.0),
                            startRadius: 4, endRadius: 50
                        )
                        .blendMode(.plusLighter)
                    )

                Image(systemName: category.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.tagline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(category.tint)
                Text("\(store.articles(in: category).count) articles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("Read at your own pace, or search to jump straight in.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(category.tint.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))

            TextField(
                "",
                text: $query,
                prompt: Text("Search in \(category.displayName)").foregroundStyle(.white.opacity(0.7))
            )
            .focused($searchFocused)
            .submitLabel(.done)
            .onSubmit { searchFocused = false }
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
        .font(.system(size: 16))
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - Articles

    @ViewBuilder
    private var articleList: some View {
        if filteredArticles.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filteredArticles.enumerated()), id: \.element.id) { idx, article in
                    Button {
                        pushedArticleId = article.id
                    } label: {
                        ArticleListRow(
                            article: article,
                            categoryTint: category.tint,
                            showDivider: idx < filteredArticles.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 30)

            Text("No matches in this category")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text("Try a different keyword, or browse other topics from the Help home.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Article row

private struct ArticleListRow: View {
    let article: HelpArticle
    let categoryTint: Color
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Lead bullet (matches category tint).
                Circle()
                    .fill(categoryTint.opacity(0.18))
                    .overlay(Circle().fill(categoryTint).frame(width: 6, height: 6))
                    .frame(width: 14, height: 14)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        if article.isPopular {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8, weight: .heavy))
                                Text("POPULAR")
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(0.6)
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15), in: .capsule)
                        }

                        if let mins = article.readTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("\(mins) min read")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 40)
            }
        }
    }
}
