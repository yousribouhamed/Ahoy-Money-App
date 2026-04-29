import SwiftUI

/// Dedicated search screen for the Help Center.
///
/// Three states:
/// • **Empty query** — show recent searches + trending topics
/// • **Has results** — show ranked articles, grouped by category
/// • **No results** — friendly empty state with "Contact us" escape hatch
///
/// We auto-focus the field on appear so the user can start typing immediately.
struct HelpSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HelpStore.self) private var store

    @State private var query: String = ""
    @State private var pushedArticleId: UUID? = nil
    @FocusState private var searchFocused: Bool

    /// Live results — recomputed on every keystroke. The store is small (~25
    /// articles) so this is essentially free.
    private var results: [HelpArticle] {
        store.search(query)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                searchHeader

                if trimmedQuery.isEmpty {
                    suggestionState
                } else if results.isEmpty {
                    emptyResultsState
                } else {
                    resultsList
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $pushedArticleId) { id in
            HelpArticleView(articleId: id)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                searchFocused = true
            }
        }
        .onSubmit(of: .search) {
            store.recordSearch(trimmedQuery)
        }
    }

    // MARK: - Header (back + search)

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
                    .foregroundStyle(.white.opacity(0.7))

                TextField(
                    "",
                    text: $query,
                    prompt: Text("Search help…").foregroundStyle(.white.opacity(0.7))
                )
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit {
                    store.recordSearch(trimmedQuery)
                }
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
        }
        .padding(.horizontal, 19)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Suggestion state (no query)

    private var suggestionState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !store.recentSearches.isEmpty {
                    section(title: "Recent searches", icon: "clock") {
                        VStack(spacing: 0) {
                            ForEach(Array(store.recentSearches.enumerated()), id: \.offset) { idx, term in
                                Button {
                                    query = term
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.55))
                                        Text(term)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if idx < store.recentSearches.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 1)
                                        .padding(.leading, 38)
                                }
                            }
                        }
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                    .scrollEdgeBlur()
                }

                section(title: "Trending now", icon: "flame.fill") {
                    FlowChips(
                        items: store.trendingTopics
                    ) { picked in
                        query = picked
                    }
                }
                .scrollEdgeBlur()

                section(title: "Quick categories", icon: "square.grid.2x2.fill") {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        ForEach(HelpCategory.allCases) { c in
                            Button { query = c.displayName } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(c.gradient)
                                        Image(systemName: c.icon)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 28, height: 28)

                                    Text(c.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    Spacer(minLength: 0)
                                }
                                .padding(8)
                                .background(Theme.card, in: .rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollEdgeBlur()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Results list

    private var resultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text("\(results.count)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                    Text(results.count == 1 ? "result for" : "results for")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\u{201C}\(trimmedQuery)\u{201D}")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { idx, article in
                        Button {
                            store.recordSearch(trimmedQuery)
                            pushedArticleId = article.id
                        } label: {
                            ResultRow(
                                article: article,
                                query: trimmedQuery,
                                showDivider: idx < results.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Theme.card, in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    // MARK: - Empty results

    private var emptyResultsState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: 100, height: 100)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            Text("No matches for \u{201C}\(trimmedQuery)\u{201D}")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Try different keywords, or ask our team — they'll get you the right answer.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let url = URL(string: "mailto:help@ahoy.ae?subject=Help%20with:%20\(trimmedQuery)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Email our team")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white, in: .capsule)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section header helper

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            content()
        }
    }
}

// MARK: - Search result row

private struct ResultRow: View {
    let article: HelpArticle
    let query: String
    let showDivider: Bool

    private var snippet: String {
        // Pull a short ~120 char snippet around the first match for context.
        let lower = article.answer.lowercased()
        guard let r = lower.range(of: query.lowercased()) else {
            return String(article.answer.prefix(120)) + "…"
        }
        let lower2 = article.answer
        let start = lower2.index(r.lowerBound, offsetBy: -40, limitedBy: lower2.startIndex) ?? lower2.startIndex
        let end = lower2.index(r.upperBound, offsetBy: 80, limitedBy: lower2.endIndex) ?? lower2.endIndex
        let prefix = start > lower2.startIndex ? "…" : ""
        let suffix = end < lower2.endIndex ? "…" : ""
        let body = String(lower2[start..<end])
            .replacingOccurrences(of: "\n", with: " ")
        return prefix + body + suffix
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(article.category.gradient)
                    Image(systemName: article.category.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.question)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(snippet)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.leading, 58)
            }
        }
    }
}

// MARK: - Flow chips (wrapping rows)

/// Single-row horizontally scrolling chips. Simple, fast, looks good on every
/// device size. Wrapping flow layout would need iOS 16+ Layout protocol; this
/// is sufficient and reads as a tag cloud either way.
private struct FlowChips: View {
    let items: [String]
    let action: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button { action(item) } label: {
                        Text(item)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }
}
