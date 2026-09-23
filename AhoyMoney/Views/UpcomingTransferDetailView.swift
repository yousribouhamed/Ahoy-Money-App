import SwiftUI

/// Full detail of a single scheduled transfer.
///
/// Layout:
/// • Top bar — back, "Schedule" title, ellipsis menu (Edit, Pause/Resume, Cancel)
/// • Hero — large amount, "to {recipient}", frequency pill
/// • Schedule glass card — frequency, next date, occurrences progress, end rule
/// • Source + recipient cards
/// • Note (if any)
/// • Recent executions timeline
/// • Primary actions row — Pause/Resume, Skip next
/// • Cancel (destructive) at the bottom
struct UpcomingTransferDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UpcomingTransferStore.self) private var store
    @Environment(BeneficiaryStore.self) private var beneficiaries

    let transferId: UUID

    @State private var showCancelConfirm: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    private var transfer: UpcomingTransfer? {
        store.items.first(where: { $0.id == transferId })
    }

    private var beneficiary: Beneficiary? {
        guard let t = transfer else { return nil }
        if let exact = beneficiaries.items.first(where: { $0.id == t.beneficiaryId }) {
            return exact
        }
        let pool = beneficiaries.items
        guard !pool.isEmpty else { return nil }
        return pool[abs(t.id.hashValue) % pool.count]
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            if let t = transfer {
                ScrollView {
                    VStack(spacing: 22) {
                        hero(t)
                        scheduleCard(t)
                        if let note = t.note, !note.isEmpty {
                            noteCard(note)
                        }
                        sourceCard(t)
                        recipientCard
                        if !t.history.isEmpty {
                            historySection(t)
                        }
                        actionRow(t)
                        cancelButton
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .scrollEdgeBlur()
            } else {
                missingState
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
        .confirmationDialog(
            "Cancel this scheduled transfer?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel transfer", role: .destructive) {
                if let t = transfer {
                    store.remove(t)
                    dismiss()
                }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This will stop all future occurrences. Past payments stay in your history.")
        }
        .liquidGlassToast(
            isPresented: $showToast,
            message: toastMessage,
            duration: 1.6
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Schedule")
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

                Menu {
                    if let t = transfer {
                        if t.status == .active {
                            Button {
                                store.pause(t)
                                toast("Schedule paused")
                            } label: {
                                Label("Pause", systemImage: "pause.circle")
                            }
                        } else if t.status == .paused {
                            Button {
                                store.resume(t)
                                toast("Schedule resumed")
                            } label: {
                                Label("Resume", systemImage: "play.circle")
                            }
                        }
                        if t.frequency != .once && t.status != .completed {
                            Button {
                                store.skipNext(t)
                                toast("Next charge skipped")
                            } label: {
                                Label("Skip next charge", systemImage: "forward.end.circle")
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            showCancelConfirm = true
                        } label: {
                            Label("Cancel schedule", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(_ t: UpcomingTransfer) -> some View {
        VStack(spacing: 14) {
            // Avatar with status ring.
            ZStack {
                Circle()
                    .strokeBorder(statusRing(for: t.status).opacity(0.5), lineWidth: 2)
                    .frame(width: 96, height: 96)
                ZStack {
                    Circle().fill(beneficiary?.avatarBg ?? Theme.accent.opacity(0.3))
                    Text(beneficiary?.initial ?? "?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 84, height: 84)
            }

            VStack(spacing: 6) {
                Text("\(t.currency) \(UpcomingTransfer.format(t.amount))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()

                Text("to \(beneficiary?.displayName ?? "Recipient")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: t.frequency.icon)
                        .font(.system(size: 10, weight: .heavy))
                    Text(t.frequency.displayName.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.2)
                }
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.accent, in: .capsule)
                .padding(.top, 4)

                if t.status != .active {
                    statusBadge(for: t.status)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.top, 4)
    }

    private func statusRing(for status: UpcomingTransferStatus) -> Color {
        switch status {
        case .active:    return Color(red: 0.34, green: 0.85, blue: 0.55)
        case .paused:    return Theme.warning
        case .completed: return .white
        case .failed:    return .red
        }
    }

    private func statusBadge(for status: UpcomingTransferStatus) -> some View {
        HStack(spacing: 6) {
            Image(systemName: status == .paused ? "pause.fill"
                              : status == .completed ? "checkmark.circle.fill"
                              : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .heavy))
            Text(status == .paused ? "Paused"
                 : status == .completed ? "Completed"
                 : "Failed")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(statusRing(for: status))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(statusRing(for: status).opacity(0.15), in: .capsule)
    }

    // MARK: - Schedule card

    @ViewBuilder
    private func scheduleCard(_ t: UpcomingTransfer) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Schedule")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }

            VStack(spacing: 10) {
                detailRow(
                    icon: "calendar.badge.clock",
                    label: "Next charge",
                    value: UpcomingTransfer.longDateFormatter.string(from: t.nextDate),
                    accent: t.daysUntilNext <= 1 && t.status == .active
                )
                Divider().background(Theme.cardOverlay)
                detailRow(
                    icon: t.frequency.icon,
                    label: "Frequency",
                    value: t.frequency.displayName
                )
                Divider().background(Theme.cardOverlay)
                detailRow(
                    icon: "flag.checkered",
                    label: "Ends",
                    value: t.endRule.displayName
                )
                if t.totalOccurrences > 0 {
                    Divider().background(Theme.cardOverlay)
                    occurrencesProgress(t)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private func occurrencesProgress(_ t: UpcomingTransfer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Progress")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Text("\(t.completedOccurrences) / \(t.totalOccurrences)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.cardOverlay)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(
                            width: geo.size.width *
                                CGFloat(min(Double(t.completedOccurrences) / Double(t.totalOccurrences), 1.0))
                        )
                }
            }
            .frame(height: 6)
        }
    }

    private func detailRow(icon: String, label: String, value: String, accent: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.accent.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent ? Theme.accent : .white)
                .lineLimit(1)
        }
    }

    // MARK: - Note card

    private func noteCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                Text("NOTE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(note)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 14))
    }

    // MARK: - Source / Recipient cards

    @ViewBuilder
    private func sourceCard(_ t: UpcomingTransfer) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.16))
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("FROM")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                Text(t.sourceLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private var recipientCard: some View {
        if let b = beneficiary {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(b.avatarBg)
                    Text(b.initial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TO")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(b.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(b.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 14))
        }
    }

    // MARK: - History timeline

    @ViewBuilder
    private func historySection(_ t: UpcomingTransfer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent activity")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(t.history.count)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
            }

            VStack(spacing: 0) {
                ForEach(Array(t.history.enumerated()), id: \.element.id) { idx, h in
                    HistoryRow(
                        entry: h,
                        currency: t.currency,
                        showLine: idx < t.history.count - 1
                    )
                }
            }
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 14))
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionRow(_ t: UpcomingTransfer) -> some View {
        HStack(spacing: 10) {
            if t.status == .active {
                actionButton(icon: "pause.fill", label: "Pause") {
                    store.pause(t)
                    toast("Schedule paused")
                }
            } else if t.status == .paused {
                actionButton(icon: "play.fill", label: "Resume") {
                    store.resume(t)
                    toast("Schedule resumed")
                }
            }

            if t.frequency != .once && t.status != .completed {
                actionButton(icon: "forward.end.fill", label: "Skip next") {
                    store.skipNext(t)
                    toast("Next charge skipped")
                }
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.cardOverlay, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.strokeSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var cancelButton: some View {
        Button {
            showCancelConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                Text("Cancel schedule")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.red.opacity(0.10), in: .capsule)
            .overlay(Capsule().strokeBorder(Color.red.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Missing

    private var missingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("Schedule not found")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Button("Go back") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.accent, in: .capsule)
                .buttonStyle(.plain)
                .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showToast = true
        }
    }
}

// MARK: - History row

private struct HistoryRow: View {
    let entry: TransferHistoryEntry
    let currency: String
    let showLine: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.18))
                        .frame(width: 24, height: 24)
                    Image(systemName: entry.status == .completed ? "checkmark"
                                      : entry.status == .failed ? "xmark"
                                      : "circle")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(statusColor)
                }
                if showLine {
                    Rectangle()
                        .fill(Theme.cardOverlayHigh)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(UpcomingTransfer.longDateFormatter.string(from: entry.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(entry.status == .completed ? "Sent successfully"
                     : entry.status == .failed ? "Failed"
                     : "Pending")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Text("\(currency) \(UpcomingTransfer.format(entry.amount))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, showLine ? 8 : 4)
    }

    private var statusColor: Color {
        switch entry.status {
        case .completed: return Color(red: 0.34, green: 0.85, blue: 0.55)
        case .failed:    return .red
        default:         return Theme.accent
        }
    }
}
