import SwiftUI

/// Four-step "Schedule a transfer" flow.
///
/// 1. **Recipient**  — pick from saved beneficiaries (search + suggested chips).
/// 2. **Amount**     — enter the value to send each time + optional note.
/// 3. **When**       — frequency, start date, end rule (never / on date / after N).
/// 4. **Review**     — summary + Face ID confirm → push success view.
///
/// On success, push `ScheduleTransferSuccessView` and dismiss back to the list.
struct ScheduleTransferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UpcomingTransferStore.self) private var store
    @Environment(BeneficiaryStore.self) private var beneficiaries

    // MARK: - Step state
    @State private var step: Int = 0
    private let totalSteps = 4

    // MARK: - Recipient
    @State private var recipient: Beneficiary? = nil
    @State private var search: String = ""

    // MARK: - Amount
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var currency: String = "AED"
    @FocusState private var amountFocused: Bool

    // MARK: - When
    @State private var frequency: TransferFrequency = .monthly
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var endChoice: EndChoice = .never
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 12, to: Date()) ?? Date()
    @State private var endCount: Int = 12

    enum EndChoice: Hashable, CaseIterable {
        case never, onDate, after
        var label: String {
            switch self {
            case .never:  return "Until I cancel"
            case .onDate: return "On a date"
            case .after:  return "After N payments"
            }
        }
    }

    // MARK: - Result
    @State private var issued: UpcomingTransfer? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                ProgressSegments(total: totalSteps, active: step + 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        stepHeader
                        stepBody
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .scrollEdgeBlur()

                Spacer(minLength: 0)

                bottomBar
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .padding(.horizontal, 19)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .headerBlurBackground()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $issued) { t in
            ScheduleTransferSuccessView(transfer: t) {
                dismiss()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text(stepTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack {
                Button {
                    if step == 0 { dismiss() }
                    else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step -= 1 }
                    }
                } label: {
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

    private var stepTitle: String {
        switch step {
        case 0: return "Pick a recipient"
        case 1: return "Amount"
        case 2: return "When?"
        case 3: return "Review"
        default: return ""
        }
    }

    // MARK: - Step header

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stepTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(stepSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0: return "Pick someone you've sent to before, or add a new beneficiary first."
        case 1: return "How much should we send each time?"
        case 2: return "Choose how often this transfer should run."
        case 3: return "Review the details. Face ID will confirm the schedule."
        default: return ""
        }
    }

    // MARK: - Step body

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case 0: recipientStep
        case 1: amountStep
        case 2: whenStep
        case 3: reviewStep
        default: EmptyView()
        }
    }

    // MARK: - Step 0: Recipient

    private var recipientStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search field.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
                TextField(
                    "",
                    text: $search,
                    prompt: Text("Search beneficiaries").foregroundStyle(Theme.textSecondary)
                )
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .tint(.white)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .frame(height: 44)
            .glassEffect(.regular.interactive(), in: .capsule)

            VStack(spacing: 0) {
                ForEach(Array(filteredBeneficiaries().enumerated()), id: \.element.id) { idx, b in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            recipient = b
                            currency = b.currency ?? "AED"
                        }
                    } label: {
                        BeneficiaryPickerRow(
                            beneficiary: b,
                            selected: recipient?.id == b.id,
                            showDivider: idx < filteredBeneficiaries().count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))

            if filteredBeneficiaries().isEmpty {
                emptyBeneficiaries
            }
        }
    }

    private var emptyBeneficiaries: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("No matches")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Add a beneficiary first, then come back to schedule.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    private func filteredBeneficiaries() -> [Beneficiary] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return beneficiaries.items }
        return beneficiaries.items.filter {
            $0.name.lowercased().contains(q)
            || ($0.nickname?.lowercased().contains(q) ?? false)
            || $0.subtitle.lowercased().contains(q)
        }
    }

    // MARK: - Step 1: Amount

    private var amountStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Big amount display.
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(currency)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                    TextField(
                        "",
                        text: $amountText,
                        prompt: Text("0.00").foregroundStyle(Theme.textSecondary)
                    )
                    .focused($amountFocused)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .multilineTextAlignment(.leading)
                    .monospacedDigit()
                }

                if let r = recipient {
                    Text("each \(frequency.shortName.lowercased()) charge to \(r.displayName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 18))

            // Quick chips.
            HStack(spacing: 8) {
                ForEach([100, 250, 500, 1000], id: \.self) { v in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            amountText = "\(v)"
                        }
                    } label: {
                        Text("\(currency) \(v)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.cardOverlay, in: .capsule)
                            .overlay(Capsule().strokeBorder(Theme.strokeSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Note field.
            VStack(alignment: .leading, spacing: 8) {
                Text("Note (optional)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                TextField(
                    "",
                    text: $note,
                    prompt: Text("e.g. Rent share, allowance").foregroundStyle(Theme.textSecondary)
                )
                .darkFieldStyle()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { amountFocused = true }
        }
    }

    // MARK: - Step 2: When

    private var whenStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Frequency grid.
            VStack(alignment: .leading, spacing: 10) {
                Text("Frequency")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(TransferFrequency.allCases) { f in
                        FrequencyTile(
                            frequency: f,
                            selected: frequency == f
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                frequency = f
                            }
                        }
                    }
                }
            }

            // Start date.
            VStack(alignment: .leading, spacing: 10) {
                Text("Start date")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                DatePicker(
                    "",
                    selection: $startDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }

            // End rule (only for recurring).
            if frequency != .once {
                VStack(alignment: .leading, spacing: 10) {
                    Text("End")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)

                    VStack(spacing: 8) {
                        ForEach(EndChoice.allCases, id: \.self) { c in
                            EndChoiceRow(
                                choice: c,
                                selected: endChoice == c,
                                endDate: $endDate,
                                endCount: $endCount
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    endChoice = c
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.card, in: .rect(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Step 3: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero summary.
            VStack(spacing: 6) {
                Text("\(currency) \(amountText.isEmpty ? "0.00" : amountText)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Text("to \(recipient?.displayName ?? "Recipient")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: frequency.icon)
                        .font(.system(size: 10, weight: .heavy))
                    Text(frequency.displayName.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                }
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.accent, in: .capsule)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.card, in: .rect(cornerRadius: 18))

            // Detail rows.
            VStack(spacing: 0) {
                ReviewRow(label: "From", value: "Ahoy Wallet")
                Divider().background(Theme.cardOverlay)
                ReviewRow(
                    label: "Starts",
                    value: UpcomingTransfer.longDateFormatter.string(from: startDate)
                )
                Divider().background(Theme.cardOverlay)
                ReviewRow(label: "Ends", value: makeEndRule().displayName)
                if let n = noteOrNil() {
                    Divider().background(Theme.cardOverlay)
                    ReviewRow(label: "Note", value: n)
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 14))

            // Trust footer.
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Schedules are encrypted. Face ID confirms each new schedule — never the recurring charges.")
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.accent)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.10), in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(Theme.cardOverlay)
            HStack {
                PrimaryWhiteButton(title: primaryTitle, enabled: canAdvance) {
                    advance()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
    }

    private var primaryTitle: String {
        step == totalSteps - 1 ? "Confirm with Face ID" : "Continue"
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return recipient != nil
        case 1: return parsedAmount() > 0
        case 2: return true
        case 3: return true
        default: return false
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step += 1 }
            return
        }
        // Final step — Face ID then create.
        BiometricAuth.authenticate(reason: "Authenticate to schedule this transfer") { ok in
            guard ok, let r = recipient else { return }
            let amount = parsedAmount()
            let totalOcc: Int = {
                switch endChoice {
                case .after: return endCount
                case .never, .onDate: return frequency == .once ? 1 : 0
                }
            }()
            let endRule = makeEndRule()
            let next = frequency == .once
                ? startDate
                : startDate

            let t = UpcomingTransfer(
                beneficiaryId: r.id,
                amount: Decimal(amount),
                currency: currency,
                frequency: frequency,
                startDate: startDate,
                nextDate: next,
                endRule: endRule,
                status: .active,
                note: noteOrNil(),
                totalOccurrences: totalOcc,
                completedOccurrences: 0,
                history: []
            )
            store.add(t)
            issued = t
        }
    }

    // MARK: - Helpers

    private func parsedAmount() -> Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func noteOrNil() -> String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func makeEndRule() -> TransferEndRule {
        if frequency == .once { return .afterOccurrences(1) }
        switch endChoice {
        case .never:  return .never
        case .onDate: return .onDate(endDate)
        case .after:  return .afterOccurrences(endCount)
        }
    }
}

// MARK: - Beneficiary picker row

private struct BeneficiaryPickerRow: View {
    let beneficiary: Beneficiary
    let selected: Bool
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
                    Text(beneficiary.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(selected ? Theme.accent : Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 12, height: 12)
                    }
                }
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
}

// MARK: - Frequency tile

private struct FrequencyTile: View {
    let frequency: TransferFrequency
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? Theme.accent : Theme.accent.opacity(0.18))
                    Image(systemName: frequency.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selected ? Theme.accentDeep : Theme.accent)
                }
                .frame(width: 28, height: 28)

                Text(frequency.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.18) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.accent : Theme.cardOverlay,
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - End choice row

private struct EndChoiceRow: View {
    let choice: ScheduleTransferView.EndChoice
    let selected: Bool
    @Binding var endDate: Date
    @Binding var endCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .strokeBorder(selected ? Theme.accent : Color.white.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if selected {
                            Circle().fill(Theme.accent).frame(width: 12, height: 12)
                        }
                    }
                    Text(choice.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }

                if selected && choice == .onDate {
                    DatePicker(
                        "",
                        selection: $endDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 34)
                }

                if selected && choice == .after {
                    HStack(spacing: 12) {
                        Spacer().frame(width: 22)
                        Stepper("After \(endCount) payment\(endCount == 1 ? "" : "s")",
                                value: $endCount, in: 1...60)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .tint(Theme.accent)
                    }
                    .padding(.leading, 12)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review row

private struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}
