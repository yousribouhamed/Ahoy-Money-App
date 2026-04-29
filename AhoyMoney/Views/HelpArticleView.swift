import SwiftUI
import UIKit

/// Full article detail screen.
///
/// Layout:
/// • Top bar with category-tinted hairline accent (back, share)
/// • Category chip + question (large bold)
/// • Read-time + popular badge
/// • Body — markdown-style rendering (paragraphs, lists, **bold**, *italic*)
/// • "Was this helpful?" — thumbs up / down
/// • "Related articles" — same category or hand-wired related IDs
/// • "Still need help?" CTA at the bottom
struct HelpArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HelpStore.self) private var store

    let articleId: UUID

    @State private var feedback: Feedback = .none
    @State private var pushedArticleId: UUID? = nil
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    enum Feedback { case none, helpful, notHelpful }

    private var article: HelpArticle? {
        store.article(by: articleId)
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            if let article {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(article: article).scrollEdgeBlur()
                        body(for: article).scrollEdgeBlur()
                        feedbackSection.scrollEdgeBlur()
                        relatedSection(article: article).scrollEdgeBlur()
                        contactCTA.scrollEdgeBlur()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
            }
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
        .liquidGlassToast(
            isPresented: $showToast,
            message: toastMessage,
            duration: 1.5
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Help")
                .font(.system(size: 18, weight: .semibold))
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

                if let article = article {
                    Button {
                        let shareText = "\(article.question)\n\n\(article.answer)"
                        let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?
                            .keyWindow?
                            .rootViewController?
                            .present(av, animated: true)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .tint(.white)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(article: HelpArticle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category chip.
            HStack(spacing: 6) {
                Image(systemName: article.category.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text(article.category.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(article.category.gradient, in: .capsule)

            Text(article.question)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Meta row.
            HStack(spacing: 8) {
                if article.isPopular {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .heavy))
                        Text("Popular")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
                }

                if let mins = article.readTime {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(mins) min read")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Body (markdown-light)

    @ViewBuilder
    private func body(for article: HelpArticle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(parseAnswer(article.answer)) { block in
                switch block.kind {
                case .paragraph:
                    Text(attributed(block.text))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                case .bullet:
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(attributed(block.text))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }

                case .numbered:
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(block.index ?? 0).")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 18, alignment: .leading)
                        Text(attributed(block.text))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(spacing: 10) {
            if feedback == .none {
                Text("Was this helpful?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    feedbackChip(label: "Yes, thanks", systemName: "hand.thumbsup.fill") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            feedback = .helpful
                        }
                        toast("Thanks for the feedback!")
                    }
                    feedbackChip(label: "Not really", systemName: "hand.thumbsdown.fill") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            feedback = .notHelpful
                        }
                        toast("Got it — we'll do better.")
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: feedback == .helpful ? "checkmark.circle.fill" : "ellipsis.message.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(
                        feedback == .helpful
                        ? "Glad it helped — we use this to improve our docs."
                        : "Sorry this wasn't useful — try contacting our team below."
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(12)
                .background(Theme.accent.opacity(0.10), in: .rect(cornerRadius: 12))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    private func feedbackChip(label: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Theme.accent.opacity(0.12))
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Related

    @ViewBuilder
    private func relatedSection(article: HelpArticle) -> some View {
        let related = store.related(to: article)
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Related articles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                VStack(spacing: 0) {
                    ForEach(Array(related.enumerated()), id: \.element.id) { idx, r in
                        Button {
                            pushedArticleId = r.id
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(r.category.gradient)
                                    Image(systemName: r.category.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 28, height: 28)

                                Text(r.question)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if idx < related.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, 50)
                        }
                    }
                }
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }
        }
    }

    // MARK: - Contact CTA

    private var contactCTA: some View {
        VStack(spacing: 8) {
            Text("Still stuck?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("Our team replies in under 2 minutes.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)

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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Helpers

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showToast = true }
    }

    /// Renders **bold** and *italic* via AttributedString. SwiftUI handles the rest.
    private func attributed(_ text: String) -> AttributedString {
        if let attr = try? AttributedString(markdown: text) {
            return attr
        }
        return AttributedString(text)
    }

    /// Lightweight parser that turns the seeded markdown-ish answer into typed
    /// blocks (paragraph, bullet, numbered). Handles the formats we author.
    private func parseAnswer(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var paragraphBuffer: [String] = []

        func flushParagraph() {
            let joined = paragraphBuffer.joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            if !joined.isEmpty {
                blocks.append(Block(kind: .paragraph, text: joined, index: nil))
            }
            paragraphBuffer = []
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                continue
            }
            // Bullet list?
            if line.hasPrefix("- ") {
                flushParagraph()
                let body = String(line.dropFirst(2))
                blocks.append(Block(kind: .bullet, text: body, index: nil))
                continue
            }
            // Numbered list?  "1. ", "2. " …
            if let numEnd = line.firstIndex(of: "."),
               let num = Int(line[line.startIndex..<numEnd]),
               line.distance(from: numEnd, to: line.endIndex) > 1
            {
                let after = line.index(numEnd, offsetBy: 2, limitedBy: line.endIndex) ?? line.endIndex
                flushParagraph()
                blocks.append(Block(kind: .numbered, text: String(line[after...]), index: num))
                continue
            }
            paragraphBuffer.append(line)
        }
        flushParagraph()
        return blocks
    }

    private struct Block: Identifiable {
        let id = UUID()
        let kind: Kind
        let text: String
        let index: Int?
        enum Kind { case paragraph, bullet, numbered }
    }
}
