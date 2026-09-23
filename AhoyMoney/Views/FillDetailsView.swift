import SwiftUI

/// Fill Details — one screen with two exits.
///
/// The identity check has already read the Emirates ID, so this screen shows
/// what it read and asks the customer to check it. **Confirm and they take the
/// instant path. Edit anything and they take the review path**, because an
/// edited field is no longer what the document said.
///
/// The consequence is stated before they edit rather than after, so someone
/// deciding whether to correct a misread name knows what it costs while they're
/// deciding.
struct FillDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OnboardingStore.self) private var onboarding

    /// Called with whether this file needs a person to look at it.
    var onContinue: (Bool) -> Void = { _ in }

    @State private var answers = OnboardingAnswers()
    @State private var employerName: String = ""
    @State private var address: String = ""

    /// Local copy so edits are tracked against what the card said.
    @State private var identity: IdentityDetails = .scannedSample

    /// The compliance question set, split by the kind of thinking each asks for.
    ///
    /// Regulator wording sits underneath each question in small print; the
    /// customer reads the rewrite. Every picker is placeholder — the values
    /// behind them are still owed.
    ///
    /// Split into three literal arrays rather than one array filtered by id:
    /// a question belongs to exactly one section *by construction*, so there's
    /// no way to add one and have it appear twice or vanish. Every follow-up
    /// sits in the same array as its parent, which is what keeps
    /// `ConditionalQuestionList`'s visibility and pruning correct on a subset.

    /// Who you are and what you do — sits with employer and address.
    ///
    /// Computed rather than a constant because an invited worker gets one extra
    /// question: their employer is already known, so the only thing worth
    /// asking is whether that employer is the one paying them.
    private var aboutQuestions: [OnboardingQuestion] {
        var list = baseAboutQuestions
        if case .invited = onboarding.resolvedPath {
            list.insert(
                .init(id: "employer_pays_salary",
                      title: "Does this employer pay your salary?",
                      complianceName: "Salary paid by named employer",
                      kind: .choice(["Yes", "No"])),
                at: 0
            )
        }
        return list
    }

    private let baseAboutQuestions: [OnboardingQuestion] = [
        .init(id: "residency",
              title: "Do you live in the UAE?",
              complianceName: "Residency status",
              kind: .choice(["Yes, I live here", "No, I'm visiting", "I've just moved here"])),

        // Moved up from the middle of the old list. This is the same question
        // about a person's working life as "Employer" and belongs next to it.
        .init(id: "occupation",
              title: "What's your occupation?",
              complianceName: "Occupation",
              kind: .choice(["Employed", "Self-employed", "Student", "Retired", "Something else"]))
    ]

    /// Forward-looking — what the customer expects to do with the wallet.
    private let usageQuestions: [OnboardingQuestion] = [
        .init(id: "purpose",
              title: "What will you mainly use Ahoy for?",
              complianceName: "Purpose of using the service",
              helper: "Pick the closest one — you can still use it for other things.",
              kind: .choice(["Getting paid", "Sending money home", "Everyday spending", "Something else"])),
        .init(id: "purpose_other",
              title: "Tell us what you'll use it for",
              complianceName: "Purpose of using the service — free text",
              kind: .explain(placeholder: "In your own words"),
              showWhen: .init("purpose", is: "Something else")),

        .init(id: "income_source",
              title: "Where does your money come from?",
              complianceName: "Source of funds",
              kind: .choice(["My salary", "My own business", "Savings", "Somewhere else"])),
        .init(id: "monthly_value",
              title: "About how much money will you move each month?",
              complianceName: "Expected monthly transaction value",
              // Bare numbers left the currency to guesswork.
              showsCurrency: true,
              helper: "A rough answer is fine. This is everything in and out together.",
              kind: .choice(["Less than 1,000", "1,000 to 5,000", "5,000 to 20,000", "More than 20,000"])),

        .init(id: "monthly_count",
              title: "About how many times will you use your wallet each month?",
              complianceName: "Expected monthly transaction count",
              helper: "Every payment, transfer or top up counts as one. A rough answer is fine.",
              kind: .choice(["A few times", "About once a week", "Most days", "Every day"])),

        .init(id: "international",
              title: "Will you send money to another country?",
              complianceName: "Expected cross-border activity",
              kind: .choice(["Yes", "No"])),
        .init(id: "international_where",
              title: "Which country will you send money to most?",
              complianceName: "Primary destination country",
              kind: .countryAndReference(referenceLabel: "Who you'll usually send to"),
              showWhen: .init("international", is: "Yes"))
    ]

    /// The legal ones. Grouped together because they need a different kind of
    /// care than "how often will you top up" — Chase gives its tax declaration
    /// a screen of its own for the same reason.
    private let declarationQuestions: [OnboardingQuestion] = [
        // The "acting on own behalf" declaration and its two follow-ups — the
        // third-party name and their authorisation letter — were removed at
        // the client's request. Nothing here asks for an uploaded document any
        // more; `.evidence` is unused by this set.

        // "family member or close associate" is the regulatory phrase; "close
        // family member" was narrower than the rule and would have missed
        // associates entirely. Final wording still sits with Compliance.
        .init(id: "pep",
              title: "Do you, a family member or a close associate hold a senior public position?",
              complianceName: "Politically Exposed Person (PEP)",
              helper: "Things like a government role, a judge, a senior military officer, or the head of a state-owned company.",
              isLegalDeclaration: true,
              kind: .choice(["No", "Yes"])),
        .init(id: "pep_detail",
              title: "What's the role, and whose is it?",
              complianceName: "PEP details",
              isLegalDeclaration: true,
              kind: .explain(placeholder: "The position and who holds it"),
              showWhen: .init("pep", is: "Yes")),

        .init(id: "tax_residence",
              title: "Do you pay tax in a country other than the UAE?",
              complianceName: "Tax residency",
              helper: "Most people here don't. Say no if you're not sure.",
              kind: .choice(["No", "Yes"])),
        .init(id: "tax_residence_detail",
              title: "Which country, and what's your tax number there?",
              complianceName: "Tax residency — jurisdiction and TIN",
              kind: .countryAndReference(referenceLabel: "Tax number"),
              showWhen: .init("tax_residence", is: "Yes"))
    ]

    // MARK: - Sections

    /// The four groups, in the order they're asked.
    ///
    /// Named `DetailSection` rather than `Section` so it can't be confused with
    /// SwiftUI's own.
    private enum DetailSection: Int, CaseIterable, Identifiable {
        case identity, about, usage, declarations

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .identity:     return "Your ID details"
            case .about:        return "About you"
            case .usage:        return "How you'll use Ahoy"
            case .declarations: return "A few declarations"
            }
        }

        /// Shown under the title while the section is shut, so a collapsed
        /// section still says what's inside it.
        var summary: String {
            switch self {
            case .identity:     return "What we read from your Emirates ID"
            case .about:        return "Where you live and work"
            case .usage:        return "What you'll mainly do with your wallet"
            // No longer mentions who the account is for — that declaration
            // was removed, and a summary naming a question the section no
            // longer asks is worse than no summary.
            case .declarations: return "Tax and public office"
            }
        }
    }

    /// Which one is open. Optional so all four can be shut.
    @State private var openSection: DetailSection? = .identity

    /// Set once Continue has been pressed on an incomplete form, which turns on
    /// the "still needs answers" marks. Before that, nothing is scolded for
    /// being empty — the customer hasn't claimed to be finished yet.
    @State private var didAttemptSubmit = false

    private func questions(in section: DetailSection) -> [OnboardingQuestion] {
        switch section {
        case .identity:     return []
        case .about:        return aboutQuestions
        case .usage:        return usageQuestions
        case .declarations: return declarationQuestions
        }
    }

    private func isComplete(_ section: DetailSection) -> Bool {
        switch section {
        case .identity:
            return identity.isComplete
        case .about:
            return !employerName.trimmingCharacters(in: .whitespaces).isEmpty
                && !address.trimmingCharacters(in: .whitespaces).isEmpty
                && answers.isComplete(aboutQuestions)
        case .usage:
            return answers.isComplete(usageQuestions)
        case .declarations:
            return answers.isComplete(declarationQuestions)
        }
    }

    private var allFilled: Bool {
        DetailSection.allCases.allSatisfy(isComplete)
    }

    private var firstIncomplete: DetailSection? {
        DetailSection.allCases.first { !isComplete($0) }
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        OnboardingStepper(step: 4)

                        header

                        VStack(spacing: 12) {
                            ForEach(DetailSection.allCases) { section in
                                sectionCard(section)
                                    .id(section)
                            }
                        }

                        continueBlock(proxy)
                    }
                    .padding(.horizontal, 22)
                    // The other step screens use 24pt here, but their top bar sits
                    // in a plain VStack while this one is a safeAreaInset, which
                    // lands ~4pt lower. 20 makes the gap match on screen.
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .scrollEdgeBlur()
                .safeAreaInset(edge: .top, spacing: 0) {
                    topBar.headerBlurBackground()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { identity = onboarding.identity }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("4")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 24, height: 24)
                    .background(Theme.accent, in: .circle)

                Text("Check your details")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Text("Four short sections. Open them in any order — we'll keep what you've done.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Section card

    /// One collapsible section.
    ///
    /// The collapsed header has to carry enough state that shutting a section
    /// doesn't hide anything that matters — what's inside it, whether it's
    /// done, and (for the ID section) whether an edit has put the wallet into
    /// review. A section that collapses into a bare title would make the form
    /// feel shorter by making it less honest.
    private func sectionCard(_ section: DetailSection) -> some View {
        let isOpen = openSection == section
        let done = isComplete(section)
        let flagged = didAttemptSubmit && !done

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                    openSection = isOpen ? nil : section
                }
            } label: {
                sectionHeaderRow(section, isOpen: isOpen, done: done, flagged: flagged)
            }
            .buttonStyle(.plain)

            if isOpen {
                sectionBody(section)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardOverlay)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            flagged ? Theme.warning.opacity(0.55) : Theme.strokeSubtle,
                            lineWidth: flagged ? 1.5 : 1
                        )
                )
        )
    }

    private func sectionHeaderRow(
        _ section: DetailSection,
        isOpen: Bool,
        done: Bool,
        flagged: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            statusMark(done: done, flagged: flagged)

            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(statusLine(section, done: done, flagged: flagged))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(flagged ? Theme.warning : Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
                .padding(.top, 3)
        }
        .padding(16)
        .contentShape(.rect)
    }

    private func statusMark(done: Bool, flagged: Bool) -> some View {
        ZStack {
            if done {
                Circle().fill(Theme.accent).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.accentDeep)
            } else {
                Circle()
                    .strokeBorder(
                        flagged ? Theme.warning : Theme.strokeSubtle,
                        lineWidth: flagged ? 2 : 1.5
                    )
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.top, 2)
    }

    /// What the collapsed header says about the section's state.
    private func statusLine(_ section: DetailSection, done: Bool, flagged: Bool) -> String {
        // Deliberately says nothing about edits. Whether a correction sends the
        // file to a person is our process; reporting it back reads as suspicion
        // of someone who has just fixed a misread name.
        if flagged { return "Still needs your answers" }
        if done { return section == .identity ? "Confirmed as scanned" : "Done" }
        return section.summary
    }

    @ViewBuilder
    private func sectionBody(_ section: DetailSection) -> some View {
        switch section {
        case .identity:
            IdentityDetailsSection(identity: $identity, showsTitle: false)

        case .about:
            VStack(alignment: .leading, spacing: 16) {
                EmployerField(path: onboarding.resolvedPath, employerName: $employerName)

                // The address is captured here as text. The proof-of-address
                // document is an optional in-app upload, not part of this
                // screen. Proof of income isn't collected anywhere.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Home address")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    TextField(
                        "",
                        text: $address,
                        prompt: Text("Building, street, area, emirate")
                            .foregroundStyle(Color.white.opacity(0.55))
                    )
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .onboardingFieldChrome()
                }

                ConditionalQuestionList(questions: aboutQuestions, answers: answers)
            }

        case .usage, .declarations:
            ConditionalQuestionList(questions: questions(in: section), answers: answers)
        }
    }

    /// The two exits, stated at the point of leaving.
    ///
    /// Deliberately *not* disabled while incomplete. With everything visible on
    /// one scroll a dead button was survivable — you could see what you'd
    /// missed. With sections shut, a dead button is a dead end: the thing you
    /// haven't answered is behind a collapsed header. So it stays live and its
    /// job, when the form isn't finished, is to open the first section that
    /// isn't and take you there.
    private func continueBlock(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 10) {
            Button {
                guard allFilled else {
                    didAttemptSubmit = true
                    if let target = firstIncomplete {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) {
                            openSection = target
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                    return
                }
                onboarding.identity = identity
                onContinue(identity.needsManualReview)
            } label: {
                Text(buttonLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        allFilled ? Color.white : Color.white.opacity(0.35),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)

        }
        .padding(.top, 6)
    }

    /// Names the section still owed rather than a flat "Continue", so the
    /// button says what pressing it will do.
    private var buttonLabel: String {
        guard allFilled else {
            let remaining = DetailSection.allCases.filter { !isComplete($0) }.count
            return remaining == 1 ? "One section left" : "\(remaining) sections left"
        }
        // Was "Submit for review" after an edit — same leak, on the button.
        return "Confirm and continue"
    }

    private var topBar: some View {
        ZStack {
            Text("Setup Wallet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

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
        .padding(.horizontal, 19)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Identity details

/// What the card said, and what the customer says it should be.
///
/// The warning sits above the fields, not after an edit — the customer should
/// know that changing something means a wait *while they're deciding whether to
/// change it*.
/// What the identity check read off the card.
///
/// **Locked by default.** These values came from the document, so the normal
/// case is reading them, not typing. Presenting six live text fields invited
/// edits nobody meant to make and made a confirmation screen look like a form.
/// Unlocking is a deliberate act behind one button.
///
/// Nothing here mentions review. Whether an edit sends the file to a person is
/// our process, not the customer's business — telling them "someone will check
/// this" explains our workflow and reads as suspicion of them for correcting a
/// misread name. The model still tracks it (`needsManualReview`); the screen
/// just doesn't narrate it.
struct IdentityDetailsSection: View {
    @Binding var identity: IdentityDetails

    /// Off when a section header already names this group, so the title isn't
    /// printed twice.
    var showsTitle: Bool = true

    @State private var isEditing = false

    /// The four the check read. The other two were never on the card, so they
    /// are always typed and never locked.
    private var scannedFields: [IdentityDetails.Field] {
        IdentityDetails.Field.allCases.filter(\.isReadFromCard)
    }
    private var typedFields: [IdentityDetails.Field] {
        IdentityDetails.Field.allCases.filter { !$0.isReadFromCard }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                if showsTitle {
                    Text("From your Emirates ID")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                Text("We took these from your Emirates ID.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: isEditing ? 12 : 0) {
                ForEach(scannedFields) { field in
                    if isEditing {
                        editableRow(field)
                    } else {
                        readOnlyRow(field)
                    }
                }
            }
            .background(
                isEditing ? Color.clear : Theme.cardOverlay,
                in: .rect(cornerRadius: 16)
            )

            if !isEditing {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Something looks wrong")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            // Always typed — these were never on the card.
            VStack(spacing: 12) {
                ForEach(typedFields) { field in
                    editableRow(field)
                }
            }
        }
    }

    /// The resting state: a value to read, not a field to fill.
    private func readOnlyRow(_ field: IdentityDetails.Field) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(field.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 120, alignment: .leading)

                Text(identity.value(field))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if field != scannedFields.last {
                Rectangle()
                    .fill(Theme.strokeSubtle)
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }

    /// Unlocked, or one of the two that were never on the card. No "changed"
    /// marking — a correction is just a correction.
    private func editableRow(_ field: IdentityDetails.Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            TextField(
                "",
                text: Binding(
                    get: { identity.value(field) },
                    set: { identity.values[field] = $0 }
                ),
                prompt: Text(field.placeholder).foregroundStyle(Color.white.opacity(0.55))
            )
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.textPrimary)
            .tint(Theme.accent)
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

            if let helper = field.helper {
                Text(helper)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Previews

// The two exits. Confirmed goes instantly; edited waits.

#Preview("Fill Details — as scanned") {
    FillDetailsView()
        .environment(OnboardingStore())
}

#Preview("Identity — confirmed") {
    ScrollView {
        IdentityDetailsSection(identity: .constant(.scannedSample))
            .padding(22)
    }
    .background(DarkGradientBackground())
}

#Preview("Identity — name corrected") {
    var edited = IdentityDetails.scannedSample
    edited.values[.fullName] = "YOUSRI BOUHAMED ALI"
    return ScrollView {
        IdentityDetailsSection(identity: .constant(edited))
            .padding(22)
    }
    .background(DarkGradientBackground())
}
