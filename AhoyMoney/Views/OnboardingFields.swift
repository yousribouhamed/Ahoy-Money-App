import SwiftUI

// MARK: - Shared field chrome
//
// One definition of what an onboarding form field looks like, so the
// conditional questions and the employer field can't drift from the dropdowns
// already on Fill Details. Matches that screen exactly: 16pt continuous radius,
// `cardOverlay` fill, `strokeSubtle` hairline, 18pt padding.

struct OnboardingFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardOverlay)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.strokeSubtle, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func onboardingFieldChrome() -> some View { modifier(OnboardingFieldChrome()) }
}

/// Placeholder vs answered text colour, matched to the existing dropdowns.
private extension Color {
    static let fieldPlaceholder = Color.white.opacity(0.55)
}

// MARK: - Question model

/// A single question on an onboarding form.
///
/// Deliberately flat rather than nested: Compliance owns the question list and
/// it *will* change, so questions are data, and a follow-up is just another
/// question that declares what makes it appear. That keeps chains (A opens B,
/// B opens C) working without a recursive type, and lets the whole form come
/// from a server payload later without reshaping anything.
struct OnboardingQuestion: Identifiable, Hashable {
    let id: String

    /// What the customer reads. The list arrives from Compliance in regulator
    /// wording; this is the rewrite. The customer is usually a construction
    /// worker on a phone, and English is usually their second language.
    let title: String

    /// The regulator's own field name, shown underneath in small print so the
    /// mapping between the two is never lost.
    let complianceName: String
    /// Draws the dirham mark beside the answer. Set on questions whose options
    /// are bare numbers, where the currency would otherwise be guesswork.
    var showsCurrency: Bool = false

    /// A short line where a word is doing work — what counts as a transaction,
    /// or that a rough answer is fine. A precise-sounding question makes people
    /// stall on an answer they can only estimate.
    let helper: String?

    /// Legal declarations (PEP, acting for a third party) need the MLRO to sign
    /// off the wording rather than merely see it.
    let isLegalDeclaration: Bool

    let kind: Kind
    /// `nil` means always visible.
    let showWhen: Trigger?

    init(
        id: String,
        title: String,
        complianceName: String,
        showsCurrency: Bool = false,
        helper: String? = nil,
        isLegalDeclaration: Bool = false,
        kind: Kind,
        showWhen: Trigger? = nil
    ) {
        self.id = id
        self.title = title
        self.complianceName = complianceName
        self.showsCurrency = showsCurrency
        self.helper = helper
        self.isLegalDeclaration = isLegalDeclaration
        self.kind = kind
        self.showWhen = showWhen
    }

    /// Question types, including the three shapes a reveal can take.
    ///
    /// Built once so Compliance can attach any of them to any question — seven
    /// use them today and that number will move.
    enum Kind: Hashable {
        /// Values behind every picker are still owed, so these stay placeholder.
        case choice([String])
        case freeText(placeholder: String)

        // The three reveal shapes.

        /// Explain — a free text box appears.
        case explain(placeholder: String)
        /// Evidence — an upload appears, demanded at the moment of the answer
        /// rather than requested later by a reviewer.
        case evidence(prompt: String)
        /// Country and reference — a country picker and a text field together.
        case countryAndReference(referenceLabel: String)
    }

    /// Shows this question only when `parentId` has been answered with one of
    /// `answers`.
    struct Trigger: Hashable {
        let parentId: String
        let answers: Set<String>

        init(_ parentId: String, is answers: String...) {
            self.parentId = parentId
            self.answers = Set(answers)
        }
    }
}

// MARK: - Answers

/// Answers keyed by question id.
///
/// Clearing hidden answers is the whole reason this isn't a plain dictionary:
/// if someone answers "Yes", fills the follow-up, then changes to "No", the
/// follow-up disappears — and its answer must go with it, or we submit a reply
/// to a question the customer can no longer see.
@Observable
final class OnboardingAnswers {
    private(set) var values: [String: String] = [:]

    func value(for id: String) -> String { values[id] ?? "" }

    func set(_ value: String, for id: String, in questions: [OnboardingQuestion]) {
        values[id] = value
        pruneHidden(in: questions)
    }

    /// True when every currently-visible question has an answer.
    func isComplete(_ questions: [OnboardingQuestion]) -> Bool {
        visible(in: questions).allSatisfy { !value(for: $0.id).isEmpty }
    }

    /// Questions the customer should see right now, in order.
    func visible(in questions: [OnboardingQuestion]) -> [OnboardingQuestion] {
        questions.filter { isVisible($0, in: questions) }
    }

    /// A question shows when it has no trigger, or when its parent is itself
    /// visible *and* answered with a triggering value. The parent check is what
    /// makes chains collapse correctly rather than stranding a grandchild.
    func isVisible(_ question: OnboardingQuestion, in questions: [OnboardingQuestion]) -> Bool {
        guard let trigger = question.showWhen else { return true }
        guard let parent = questions.first(where: { $0.id == trigger.parentId }) else { return false }
        guard isVisible(parent, in: questions) else { return false }
        return trigger.answers.contains(value(for: trigger.parentId))
    }

    private func pruneHidden(in questions: [OnboardingQuestion]) {
        for question in questions where !isVisible(question, in: questions) {
            values.removeValue(forKey: question.id)
        }
    }
}

// MARK: - Conditional question list

/// Renders a question list, revealing and hiding follow-ups as answers change.
struct ConditionalQuestionList: View {
    let questions: [OnboardingQuestion]
    @Bindable var answers: OnboardingAnswers

    var body: some View {
        VStack(spacing: 16) {
            ForEach(answers.visible(in: questions)) { question in
                questionField(question)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: answers.values)
    }

    @ViewBuilder
    private func questionField(_ question: OnboardingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch question.kind {
            case let .choice(options):
                labelBlock(question)
                choiceField(question, options: options)

            case let .freeText(placeholder):
                labelBlock(question)
                textField(question, placeholder: placeholder)

            // Reveal shape 1 — explain.
            case let .explain(placeholder):
                labelBlock(question)
                textField(question, placeholder: placeholder)

            // Reveal shape 2 — evidence, asked for now rather than chased later.
            case let .evidence(prompt):
                labelBlock(question)
                EvidenceUpload(prompt: prompt, fileName: answers.value(for: question.id)) { name in
                    answers.set(name, for: question.id, in: questions)
                }

            // Reveal shape 3 — country and reference, together.
            case let .countryAndReference(referenceLabel):
                labelBlock(question)
                CountryAndReferenceField(
                    referenceLabel: referenceLabel,
                    value: answers.value(for: question.id)
                ) { combined in
                    answers.set(combined, for: question.id, in: questions)
                }
            }
        }
    }

    /// Customer wording on top, the regulator's field name underneath in small
    /// print, and a helper line where a word is doing work.
    @ViewBuilder
    private func labelBlock(_ question: OnboardingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(question.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let helper = question.helper {
                Text(helper)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // `complianceName` is deliberately *not* drawn. It's the
            // regulator's own term for the question — "Expected monthly
            // transaction value" — which tells the customer nothing the
            // question doesn't already say, and gave every item a second
            // subtitle at a second size. It stays on the model for the
            // Compliance mapping and leaves the screen.
        }
    }

    private func choiceField(_ question: OnboardingQuestion, options: [String]) -> some View {
        let answer = answers.value(for: question.id)
        return Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    answers.set(option, for: question.id, in: questions)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if question.showsCurrency && !answer.isEmpty {
                    CurrencyIcon(size: 15, color: Theme.textPrimary)
                        .padding(.top, 2)
                }
                Text(answer.isEmpty ? "Choose one" : answer)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(answer.isEmpty ? Color.fieldPlaceholder : Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fieldPlaceholder)
                    .padding(.top, 2)
            }
            .onboardingFieldChrome()
        }
    }

    private func textField(_ question: OnboardingQuestion, placeholder: String) -> some View {
        let binding = Binding(
            get: { answers.value(for: question.id) },
            set: { answers.set($0, for: question.id, in: questions) }
        )
        return TextField(
            "",
            text: binding,
            prompt: Text(placeholder).foregroundStyle(Color.fieldPlaceholder)
        )
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.accent)
        .onboardingFieldChrome()
    }
}

// MARK: - Reveal shape: evidence

/// An upload demanded at the moment of the answer.
///
/// Asking here rather than letting a reviewer chase it later is the whole point
/// — it turns a round trip into a single step.
private struct EvidenceUpload: View {
    let prompt: String
    let fileName: String
    let onPicked: (String) -> Void

    @State private var importing = false

    var body: some View {
        Button {
            importing = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: fileName.isEmpty ? "arrow.up.doc" : "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(fileName.isEmpty ? Theme.textSecondary : Theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName.isEmpty ? prompt : fileName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(fileName.isEmpty ? "PDF or photo" : "Tap to replace")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .onboardingFieldChrome()
        }
        .buttonStyle(.plain)
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                onPicked(url.lastPathComponent)
            }
        }
    }
}

// MARK: - Reveal shape: country and reference

/// A country picker and a text field that belong together — a tax residence and
/// its number, say. Stored as one answer so the pair can't be half-filled.
private struct CountryAndReferenceField: View {
    let referenceLabel: String
    let value: String
    let onChange: (String) -> Void

    @State private var showCountries = false

    private var country: String { value.components(separatedBy: "|").first ?? "" }
    private var reference: String {
        let parts = value.components(separatedBy: "|")
        return parts.count > 1 ? parts[1] : ""
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                showCountries = true
            } label: {
                HStack(spacing: 12) {
                    Text(country.isEmpty ? "Choose a country" : country)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(country.isEmpty ? Color.fieldPlaceholder : Color.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fieldPlaceholder)
                }
                .onboardingFieldChrome()
            }
            .buttonStyle(.plain)

            TextField(
                "",
                text: Binding(
                    get: { reference },
                    set: { onChange("\(country)|\($0)") }
                ),
                prompt: Text(referenceLabel).foregroundStyle(Color.fieldPlaceholder)
            )
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
            .onboardingFieldChrome()
        }
        .sheet(isPresented: $showCountries) {
            CountryCodeSheet { picked in
                onChange("\(picked.name)|\(reference)")
            }
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
    }
}

// MARK: - Employer field
//
// `Employer`, `EmployerDirectory` and `EnrolmentPath` live in
// Models/OnboardingStore.swift — they are onboarding model types, not view code.

/// Employer on Fill Details.
///
/// **Invited** — read only. The employer came from the invite, so it's shown as
/// settled fact rather than an input the customer might think they should change.
///
/// **Standalone** — searchable, with a free-text fallback. A worker whose
/// employer isn't in the directory must still be able to finish; refusing the
/// answer would dead-end the only path they have.
struct EmployerField: View {
    let path: EnrolmentPath
    @Binding var employerName: String
    var directory: EmployerDirectory = LocalEmployerDirectory()

    @State private var showPicker = false
    /// Whether the standalone name came from the directory or was typed. The
    /// two look different on purpose: a matched employer is confirmed back, a
    /// typed one is accepted but visibly unverified.
    @State private var matchedFromDirectory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Employer")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            switch path {
            case let .invited(employer):
                // 1. Invited — shown, not asked.
                readOnlyField(employer)
            case .standalone where employerName.isEmpty:
                // 2. Standalone, nothing chosen yet.
                searchableField
            case .standalone where matchedFromDirectory:
                // 3. Standalone, matched — confirmed back with a change link.
                confirmedField
            case .standalone:
                // 4. Standalone, no match — free text, accepted as given.
                freeTextField
            }
        }
        .onAppear {
            // The invited path's employer is fact, not input — make sure the
            // value submitted matches what's on screen.
            if case let .invited(employer) = path { employerName = employer.name }
        }
        .sheet(isPresented: $showPicker) {
            EmployerPickerSheet(
                directory: directory,
                selectedName: $employerName,
                matchedFromDirectory: $matchedFromDirectory
            )
        }
    }

    private func readOnlyField(_ employer: Employer) -> some View {
        HStack(spacing: 12) {
            Text(employer.name)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.fieldPlaceholder)
        }
        .onboardingFieldChrome()
        .overlay(alignment: .bottomLeading) {
            Text("Added by your employer when they invited you")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .offset(y: 22)
        }
        .padding(.bottom, 22)
    }

    /// Matched against the directory — the name is read back so the customer
    /// can see we recognised it, with a way out if it's the wrong one.
    private var confirmedField: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)

            Text(employerName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Button("Change") { showPicker = true }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
        }
        .onboardingFieldChrome()
    }

    /// No match in the directory. Their answer stands — refusing it would dead
    /// end the only path they have — but it isn't dressed up as confirmed.
    private var freeTextField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(employerName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Change") { showPicker = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain)
            }
            .onboardingFieldChrome()

            Text("Not in our list — we'll check this when we review your account.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchableField: some View {
        Button {
            showPicker = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(employerName.isEmpty ? "Search for your employer" : employerName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(employerName.isEmpty ? Color.fieldPlaceholder : Color.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fieldPlaceholder)
                    .padding(.top, 2)
            }
            .onboardingFieldChrome()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Employer picker

/// Search sheet with a free-text fallback.
private struct EmployerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let directory: EmployerDirectory
    @Binding var selectedName: String
    /// True when the name came from the directory, false when the customer
    /// typed their own. The field renders differently for each.
    @Binding var matchedFromDirectory: Bool

    @State private var query: String = ""
    @State private var results: [Employer] = []
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                searchHeader

                if isSearching {
                    Spacer()
                    ProgressView().tint(Theme.accent)
                    Spacer()
                } else if results.isEmpty {
                    noResults
                } else {
                    resultsList
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            results = await directory.search("")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { searchFocused = true }
        }
        .onChange(of: query) { _, newValue in
            Task {
                isSearching = true
                results = await directory.search(newValue)
                isSearching = false
            }
        }
    }

    private var searchHeader: some View {
        VStack(spacing: 14) {
            Text("Your employer")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                TextField(
                    "",
                    text: $query,
                    prompt: Text("Search company name").foregroundStyle(Theme.textSecondary)
                )
                .focused($searchFocused)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)

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
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    /// Offered alongside the matches, not only when there are none. Typing
    /// three letters of a company that *is* listed used to hide this, so an
    /// employer we don't carry was unreachable unless the search came back
    /// completely empty.
    @ViewBuilder
    private var useTypedNameRow: some View {
        if !trimmedQuery.isEmpty && !results.contains(where: { $0.name.caseInsensitiveCompare(trimmedQuery) == .orderedSame }) {
            Button {
                choose(trimmedQuery, matched: false)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use \u{201C}\(trimmedQuery)\u{201D}")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Text("Not in the list")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, employer in
                    Button {
                        choose(employer.name, matched: true)
                    } label: {
                        row(employer)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Theme.cardOverlay)
                        .frame(height: 1)
                        .padding(.leading, 16)
                }

                useTypedNameRow
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ employer: Employer) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(employer.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                if let trade = employer.trade {
                    Text(trade)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if employer.name == selectedName {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// The fallback. A customer whose employer isn't listed still has to be able
    /// to finish — so what they typed is a valid answer, and we say plainly that
    /// it will be checked rather than pretending it matched something.
    private var noResults: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "building.2")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)

            Text("We don't have that one listed")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("You can use the name you typed instead.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if !trimmedQuery.isEmpty {
                Button {
                    choose(trimmedQuery, matched: false)
                } label: {
                    Text("Use “\(trimmedQuery)”")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer()
        }
    }

    private func choose(_ name: String, matched: Bool) {
        selectedName = name
        matchedFromDirectory = matched
        dismiss()
    }
}

// MARK: - Invite code

/// Where the invited path begins.
///
/// **Placeholder mechanism.** How an invited worker actually arrives isn't
/// confirmed — most likely a deep link from an invite message. A typed code is
/// the version that can be demonstrated without a backend, and a deep link
/// would call the same `resolve` step, so only the entry point changes.
///
/// Demo: any code beginning "AHOY" resolves to an employer.
struct InviteCodeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var resolver: InviteResolver = LocalInviteResolver()
    let onResolved: (Employer) -> Void

    /// The two failures get opposite treatments, because they need opposite
    /// things from the customer.
    ///
    /// A **wrong** code stays inline: what they typed is preserved, the field is
    /// marked, and they fix a character. Replacing the screen would throw away
    /// the code and make a typo feel like a wall.
    ///
    /// An **expired** code replaces the form entirely. Retyping it cannot work,
    /// so leaving the field sitting there only invites a second attempt at
    /// something already ruled out.
    private enum Phase {
        case entry
        case expired(employer: Employer?, on: Date?)
    }

    @State private var phase: Phase = .entry
    @State private var code: String = ""
    @State private var checking = false
    @State private var unrecognised = false
    @FocusState private var focused: Bool

    private static let errorRed = Color(red: 0.86, green: 0.18, blue: 0.24)
    /// Theme.warning (#FDC700) is tuned for the dark screens and all but
    /// disappears on this white sheet, so the amber is darkened here.
    private static let warningInk = Color(red: 0.70, green: 0.45, blue: 0.0)

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f
    }()

    private var trimmed: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Group {
            switch phase {
            case .entry:
                entryView
            case let .expired(employer, date):
                expiredView(employer: employer, on: date)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .presentationDetents([.height(detentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var detentHeight: CGFloat {
        switch phase {
        case .entry:   return 430
        case .expired: return 400
        }
    }

    // MARK: - Entry

    private var entryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite code")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text("Your employer sends this when they add you. If you don't have one, you can carry on without it — we'll just ask who you work for.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.grayText)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "",
                text: $code,
                prompt: Text("e.g. AHOY-4K2P").foregroundStyle(Theme.grayText)
            )
            .focused($focused)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .submitLabel(.go)
            .onSubmit { check() }
            .font(.system(size: 17, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.grayBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                unrecognised ? Self.errorRed : Theme.grayBorderLight,
                                lineWidth: 1
                            )
                    )
            )
            .onChange(of: code) { _, _ in unrecognised = false }

            if unrecognised {
                // Specifically about a code that doesn't exist. The expired
                // case never reaches this line — saying "we don't recognise it"
                // about a code we issued would send people to check a spelling
                // that was right all along.
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("We don't recognise that code. Check it against the message your employer sent, or carry on without it.")
                        .font(.system(size: 13, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Self.errorRed)
            }

            Spacer(minLength: 0)

            Button { check() } label: {
                HStack(spacing: 8) {
                    if checking { ProgressView().tint(.black) }
                    Text(checking ? "Checking…" : "Use this code")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    trimmed.isEmpty ? Theme.accent.opacity(0.4) : Theme.accent,
                    in: .capsule
                )
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty || checking)

            Button {
                dismiss()
            } label: {
                Text("I don't have one")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
    }

    // MARK: - Expired

    private func expiredView(employer: Employer?, on date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Self.warningInk)
                .padding(.bottom, 2)

            Text("That code has expired")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(expiredExplanation(employer: employer, on: date))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.grayText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Back to the form rather than out of the sheet: an employer who
            // reissues a code often does it while the worker is still here.
            Button {
                code = ""
                unrecognised = false
                phase = .entry
                focused = true
            } label: {
                Text("Enter a different code")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Theme.accent, in: .capsule)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("Carry on without a code")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
        }
    }

    /// Names who to go back to. "Expired" alone tells someone the door is shut
    /// without telling them who holds the key.
    ///
    /// States a date when we have one and never a duration — how long a code
    /// lasts isn't settled, and putting a number of days in copy would be a
    /// promise nobody has agreed to.
    private func expiredExplanation(employer: Employer?, on date: Date?) -> String {
        let subject = employer.map { "Your invite from \($0.name)" } ?? "That invite"
        let ask = employer == nil ? "Ask your employer" : "Ask them"
        let when = date.map { " on \(Self.dayFormatter.string(from: $0))" } ?? ""
        return "\(subject) ran out\(when). \(ask) to send you a new one, or carry on without it — we'll just ask who you work for."
    }

    private func check() {
        guard !trimmed.isEmpty else { return }
        focused = false
        checking = true
        Task {
            let outcome = await resolver.resolve(code: trimmed)
            checking = false
            switch outcome {
            case let .valid(employer):
                onResolved(employer)
                dismiss()
            case let .expired(employer, date):
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    phase = .expired(employer: employer, on: date)
                }
            case .unrecognised:
                unrecognised = true
            }
        }
    }
}
