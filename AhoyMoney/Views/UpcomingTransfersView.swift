import SwiftUI

/// Hub for all scheduled outgoing transfers — entered from the Send tab.
///
/// Layout (top → bottom):
/// • Top bar: back, "Upcoming Transfers" title, "+" glass schedule button
/// • Hero "Next up" glass card — surfaces the soonest active charge so the
///   user can act on the most relevant info without scanning the whole list.
/// • Filter chips: All / Active / Paused / Completed
/// • Date-grouped sections: This week → This month → Later → Completed
/// • Per-row: avatar, name, amount, frequency pill, next date, status dot
/// • Long-press → quick actions (Pause/Resume, Skip next, Edit, Cancel)
/// • Empty state when nothing matches
struct UpcomingTransfersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UpcomingTransferStore.self) private var store
    @Environment(BeneficiaryStore.self) private var beneficiaries

    @State private var filter: UpcomingFilter = .all
    @State private var pushedTransferId: UUID? = nil
    @State private var showSchedule: Bool = false
    @State private var showCancelConfirm: UpcomingTransfer? = nil
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 20) {
                    nextUpHero
                    filterRow
                    listContent
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .scrollEdgeBlur()
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
        .navigationDestination(item: $pushedTransferId) { id in
            UpcomingTransferDetailView(transferId: id)
        }
        .navigationDestination(isPresented: $showSchedule) {
            ScheduleTransferView()
        }
        .confirmationDialog(
            "Cancel this scheduled transfer?",
            isPresented: Binding(
                get: { showCancelConfirm != nil },
                set: { if !$0 { showCancelConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Cancel transfer", role: .destructive) {
                if let t = showCancelConfirm {
                    store.remove(t)
                    toast("Schedule cancelled")
                }
                showCancelConfirm = nil
            }
            Button("Keep it", role: .cancel) { showCancelConfirm = nil }
        } message: {
            Text("This will stop all future occurrences. Past payments stay in your history.")
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
            Text("Upcoming Transfers")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
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

                Button {
                    BiometricAuth.authenticate(reason: "Authenticate to schedule a transfer") { ok in
                        if ok { showSchedule = true }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
            }
        }
    }

    // MARK: - Next-up hero

    @ViewBuilder
    private var nextUpHero: some View {
        if let next = store.nextUpcoming {
            let beneficiary = resolve(next)
            HStack(spacing: 14) {
                avatar(for: beneficiary, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.accent)
                        Text("NEXT UP")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accent)
                    }

                    Text("\(next.currency) \(UpcomingTransfer.format(next.amount))")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()

                    HStack(spacing: 6) {
                        Text("to \(beneficiary?.displayName ?? "Recipient")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("•")
                            .foregroundStyle(Theme.textSecondary)
                        Text(next.nextRelative)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.20), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture { pushedTransferId = next.id }
        } else {
            // Smaller summary when there's nothing scheduled.
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.18))
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing scheduled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Schedule a transfer to never miss a payment.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 18))
        }
    }

    // MARK: - Filter chips

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UpcomingFilter.allCases, id: \.self) { f in
                    let active = filter == f
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            filter = f
                        }
                    } label: {
                        Text(f.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(active ? Theme.accentDeep : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(active ? Theme.accent : Theme.cardOverlay)
                                    .overlay(
                                        Capsule().strokeBorder(
                                            active ? Color.clear : Theme.strokeSubtle,
                                            lineWidth: 1
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - List content

    @ViewBuilder
    private var listContent: some View {
        let items = store.filtered(by: filter)
        if items.isEmpty {
            emptyState
        } else {
            VStack(spacing: 22) {
                ForEach(groupOrder(for: items), id: \.title) { group in
                    section(title: group.title, items: group.items)
                }
            }
        }
    }

    /// Group items into chronological buckets. Completed items get their own
    /// final section so they don't pollute the upcoming buckets.
    private func groupOrder(for items: [UpcomingTransfer]) -> [(title: String, items: [UpcomingTransfer])] {
        var thisWeek: [UpcomingTransfer] = []
        var thisMonth: [UpcomingTransfer] = []
        var later: [UpcomingTransfer] = []
        var done: [UpcomingTransfer] = []

        for t in items {
            if t.status == .completed { done.append(t); continue }
            let d = t.daysUntilNext
            switch d {
            case ..<7:                  thisWeek.append(t)
            case 7..<31:                thisMonth.append(t)
            default:                    later.append(t)
            }
        }

        var groups: [(String, [UpcomingTransfer])] = []
        if !thisWeek.isEmpty  { groups.append(("This week",  thisWeek)) }
        if !thisMonth.isEmpty { groups.append(("This month", thisMonth)) }
        if !later.isEmpty     { groups.append(("Later",      later)) }
        if !done.isEmpty      { groups.append(("Completed",  done)) }
        return groups
    }

    @ViewBuilder
    private func section(title: String, items: [UpcomingTransfer]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(items.count)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: .capsule)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, t in
                    Button {
                        pushedTransferId = t.id
                    } label: {
                        TransferRow(
                            transfer: t,
                            beneficiary: resolve(t),
                            showDivider: idx < items.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextActions(for: t) }
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func contextActions(for t: UpcomingTransfer) -> some View {
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
                Label("Skip next", systemImage: "forward.end.circle")
            }
        }

        Button {
            pushedTransferId = t.id
        } label: {
            Label("View details", systemImage: "info.circle")
        }

        Divider()

        Button(role: .destructive) {
            showCancelConfirm = t
        } label: {
            Label("Cancel schedule", systemImage: "trash")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            EmptyStateArt(name: "empty_schedule", size: 112)
                .padding(.top, 30)

            Text(filter == .all ? "No scheduled transfers yet" : "Nothing here")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text("Schedule a one-time or recurring transfer — we'll handle the rest.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                BiometricAuth.authenticate(reason: "Authenticate to schedule a transfer") { ok in
                    if ok { showSchedule = true }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Schedule transfer")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.accent, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func resolve(_ t: UpcomingTransfer) -> Beneficiary? {
        // First try by stored ID.
        if let exact = beneficiaries.items.first(where: { $0.id == t.beneficiaryId }) {
            return exact
        }
        // Fall back: deterministic mapping from amount/currency to one of the
        // seeded beneficiaries — keeps the demo readable.
        let pool = beneficiaries.items
        guard !pool.isEmpty else { return nil }
        let pick = abs(t.id.hashValue) % pool.count
        return pool[pick]
    }

    @ViewBuilder
    private func avatar(for b: Beneficiary?, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(b?.avatarBg ?? Theme.accent.opacity(0.3))
            Text(b?.initial ?? "?")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(width: size, height: size)
    }

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showToast = true
        }
    }
}

// MARK: - Row

private struct TransferRow: View {
    let transfer: UpcomingTransfer
    let beneficiary: Beneficiary?
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(beneficiary?.avatarBg ?? Theme.accent.opacity(0.3))
                    Text(beneficiary?.initial ?? "?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)

                    // Status overlay dot.
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Theme.card, lineWidth: 2))
                        .offset(x: 16, y: 16)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(beneficiary?.displayName ?? "Recipient")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        // Frequency pill.
                        Text(transfer.frequency.shortName)
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(Theme.accentDeep)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent, in: .capsule)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: transfer.status == .paused ? "pause.fill"
                                          : transfer.status == .completed ? "checkmark"
                                          : "calendar")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Theme.textSecondary)
                        Text(metaLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(transfer.currency) \(UpcomingTransfer.format(transfer.amount))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(transfer.nextRelative)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.5)
                        .foregroundStyle(transfer.daysUntilNext <= 1 && transfer.status == .active
                                         ? Theme.accent : .white.opacity(0.55))
                }
            }
            .padding(14)

            if showDivider {
                Rectangle()
                    .fill(Theme.cardOverlay)
                    .frame(height: 1)
                    .padding(.leading, 68)
            }
        }
    }

    private var statusColor: Color {
        switch transfer.status {
        case .active:    return Color(red: 0.34, green: 0.85, blue: 0.55)
        case .paused:    return Theme.warning
        case .completed: return .white.opacity(0.4)
        case .failed:    return .red
        }
    }

    private var metaLabel: String {
        switch transfer.status {
        case .active:
            return "Next \(UpcomingTransfer.shortDateFormatter.string(from: transfer.nextDate))"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}
