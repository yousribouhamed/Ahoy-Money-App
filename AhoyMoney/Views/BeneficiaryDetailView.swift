import SwiftUI

/// Full profile of a saved beneficiary.
///
/// Layout:
/// • Top bar (back, "Beneficiary" title, more-actions menu)
/// • Hero: large avatar, name, optional nickname, type badge
/// • Primary CTA: "Send Money" (white capsule)
/// • Contact + bank details cards (only show fields the beneficiary has)
/// • Pin to favorites toggle
/// • Destructive Delete row (with confirmation)
///
/// All edits round-trip through `BeneficiaryStore` so the directory and
/// Suggested carousel stay in sync.
struct BeneficiaryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BeneficiaryStore.self) private var store
    @Environment(AppRouter.self) private var router

    let beneficiary: Beneficiary

    @State private var showEdit: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    /// Latest copy from the store (so toggling favorite, editing nickname, etc. reflects live).
    private var live: Beneficiary {
        store.items.first(where: { $0.id == beneficiary.id }) ?? beneficiary
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 24) {
                    hero.scrollEdgeBlur()
                    sendCTA.scrollEdgeBlur()
                    contactCard.scrollEdgeBlur()
                    bankCard.scrollEdgeBlur()
                    favoriteCard.scrollEdgeBlur()
                    deleteButton.scrollEdgeBlur()
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
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
        .sheet(isPresented: $showEdit) {
            EditBeneficiarySheet(
                beneficiary: live,
                onSave: { updated in
                    store.update(updated)
                    toast("Beneficiary updated")
                }
            )
        }
        .confirmationDialog(
            "Delete this beneficiary?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.remove(live)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(live.displayName) will be removed from your list. You can add them again later.")
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
            Text("Beneficiary")
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

                Menu {
                    Button {
                        showEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        store.toggleFavorite(live)
                        toast(live.isFavorite ? "Unpinned from Suggested" : "Pinned to Suggested")
                    } label: {
                        Label(
                            live.isFavorite ? "Unpin from Favorites" : "Pin to Favorites",
                            systemImage: live.isFavorite ? "star.slash" : "star.fill"
                        )
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
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

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(live.avatarBg)
                Text(live.initial)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: 96, height: 96)
            .overlay(alignment: .bottomTrailing) {
                if live.isFavorite {
                    ZStack {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 28, height: 28)
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accentDeep)
                    }
                    .offset(x: 4, y: 4)
                }
            }

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(live.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    if live.kind == .wallet {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }

                if let nick = live.nickname, !nick.isEmpty, nick != live.name {
                    Text(live.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }

                KindBadgeLarge(kind: live.kind)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Send CTA

    private var sendCTA: some View {
        VStack(spacing: 10) {
            PrimaryWhiteButton(title: "Send Money") {
                // Placeholder for the future amount-entry flow. For now, return
                // to the Send tab — the user can pick the rail there.
                router.selectedTab = .send
                dismiss()
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Every transfer is verified with Face ID")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Theme.accent.opacity(0.8))
        }
    }

    // MARK: - Contact

    @ViewBuilder
    private var contactCard: some View {
        let rows = contactRows
        if !rows.isEmpty {
            DetailCard(title: "Contact") {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.label) { idx, row in
                        DetailRow(label: row.label, value: row.value, icon: row.icon)
                        if idx < rows.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                                .padding(.leading, 38)
                        }
                    }
                }
            }
        }
    }

    private var contactRows: [(label: String, value: String, icon: String)] {
        var out: [(String, String, String)] = []
        if let phone = live.phone, !phone.isEmpty {
            let code = live.phoneCode ?? ""
            out.append(("Phone", "\(code) \(phone)".trimmingCharacters(in: .whitespaces), "phone.fill"))
        }
        if let email = live.email, !email.isEmpty {
            out.append(("Email", email, "envelope.fill"))
        }
        return out
    }

    // MARK: - Bank

    @ViewBuilder
    private var bankCard: some View {
        let rows = bankRows
        if !rows.isEmpty {
            DetailCard(title: live.kind == .wallet ? "Wallet details" : "Bank details") {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.label) { idx, row in
                        DetailRow(label: row.label, value: row.value, icon: row.icon)
                        if idx < rows.count - 1 {
                            Divider().background(Color.white.opacity(0.08))
                                .padding(.leading, 38)
                        }
                    }
                }
            }
        }
    }

    private var bankRows: [(label: String, value: String, icon: String)] {
        var out: [(String, String, String)] = []

        if let bank = live.bankName, !bank.isEmpty {
            out.append(("Bank", bank, "building.columns.fill"))
        }
        if let iban = live.iban, !iban.isEmpty {
            out.append(("IBAN", maskIBAN(iban), "creditcard.fill"))
        }
        if let acct = live.accountNumber, !acct.isEmpty {
            out.append(("Account", maskIBAN(acct), "creditcard.fill"))
        }
        if let swift = live.swift, !swift.isEmpty {
            out.append(("SWIFT / BIC", swift, "globe"))
        }
        if let country = live.country, !country.isEmpty {
            out.append(("Country", country, "mappin.and.ellipse"))
        }
        if let currency = live.currency, !currency.isEmpty {
            out.append(("Currency", currency, "dollarsign.circle.fill"))
        }
        if let address = live.address, !address.isEmpty {
            out.append(("Address", address, "house.fill"))
        }

        // Always show "Added" date as a footer-ish row so the user has context.
        out.append(("Added", BeneficiaryDetailView.relativeDate(live.dateAdded), "calendar"))

        return out
    }

    // MARK: - Favorite

    private var favoriteCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.15))
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pinned to Suggested")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Always keep \(live.displayName) one tap away.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { live.isFavorite },
                set: { _ in
                    store.toggleFavorite(live)
                    toast(live.isFavorite ? "Pinned to Suggested" : "Unpinned from Suggested")
                }
            ))
            .labelsHidden()
            .tint(Theme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    // MARK: - Delete

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Delete beneficiary")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func toast(_ msg: String) {
        toastMessage = msg
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showToast = true
        }
    }

    private func maskIBAN(_ iban: String) -> String {
        let cleaned = iban.filter { $0.isLetter || $0.isNumber }.uppercased()
        guard cleaned.count > 8 else { return cleaned }
        let head = String(cleaned.prefix(4))
        let tail = String(cleaned.suffix(4))
        return "\(head) •••• •••• \(tail)"
    }

    private static func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Detail card

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 4)

            content
                .padding(.vertical, 4)
                .background(Theme.card, in: .rect(cornerRadius: 16))
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22, height: 22)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct KindBadgeLarge: View {
    let kind: BeneficiaryKind
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.accent.opacity(0.15), in: .capsule)
    }

    private var label: String {
        switch kind {
        case .wallet:        return "AHOY WALLET"
        case .uae:           return "UAE BANK"
        case .international: return "INTERNATIONAL"
        }
    }
}
