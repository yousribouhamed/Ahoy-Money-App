import Foundation
import SwiftUI

/// What kind of payout rail this beneficiary uses.
enum BeneficiaryKind: String, Hashable {
    case wallet
    case uae
    case international
}

/// A saved recipient. Drives the Suggested carousel, the Beneficiaries directory,
/// and the per-rail confirmation summary while the user is creating the entry.
///
/// Most fields are optional — populated by `AddBeneficiaryView.makeBeneficiary()`
/// based on the rail. The detail view shows whichever fields are non-nil.
struct Beneficiary: Identifiable, Hashable {
    let id: UUID
    var kind: BeneficiaryKind
    var name: String
    var nickname: String?
    var subtitle: String              // e.g. "+971 5••••••193" — masked one-liner for lists
    var avatarBg: Color
    var isFavorite: Bool
    var dateAdded: Date

    // Contact (any rail)
    var phone: String?
    var phoneCode: String?
    var email: String?

    // Bank (UAE + International)
    var bankName: String?
    var iban: String?

    // International only
    var swift: String?
    var accountNumber: String?
    var country: String?
    var currency: String?
    var address: String?

    init(
        id: UUID = UUID(),
        kind: BeneficiaryKind,
        name: String,
        nickname: String? = nil,
        subtitle: String,
        avatarBg: Color,
        isFavorite: Bool = true,
        dateAdded: Date = Date(),
        phone: String? = nil,
        phoneCode: String? = nil,
        email: String? = nil,
        bankName: String? = nil,
        iban: String? = nil,
        swift: String? = nil,
        accountNumber: String? = nil,
        country: String? = nil,
        currency: String? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.nickname = nickname
        self.subtitle = subtitle
        self.avatarBg = avatarBg
        self.isFavorite = isFavorite
        self.dateAdded = dateAdded
        self.phone = phone
        self.phoneCode = phoneCode
        self.email = email
        self.bankName = bankName
        self.iban = iban
        self.swift = swift
        self.accountNumber = accountNumber
        self.country = country
        self.currency = currency
        self.address = address
    }

    /// First glyph of the (nick)name — used as a placeholder when there's no avatar image.
    var initial: String {
        let source = (nickname?.isEmpty == false ? nickname! : name)
        return source.first.map { String($0).uppercased() } ?? "?"
    }

    /// Friendly display label — nickname if set, otherwise legal name.
    var displayName: String {
        if let nick = nickname, !nick.isEmpty { return nick }
        return name
    }
}

/// Process-wide store of saved beneficiaries.
/// Seeded with a few demo entries so the Send tab has content on first run.
@Observable
final class BeneficiaryStore {
    var items: [Beneficiary] = [
        Beneficiary(
            kind: .wallet,
            name: "Mia Alixon",
            nickname: nil,
            subtitle: "+971 5••••••231",
            avatarBg: Color(red: 0.88, green: 0.72, blue: 1.00),
            isFavorite: true,
            dateAdded: Date().addingTimeInterval(-86_400 * 7),
            phone: "501234231",
            phoneCode: "+971"
        ),
        Beneficiary(
            kind: .uae,
            name: "Zoya Khan",
            nickname: "Sister",
            subtitle: "Emirates NBD ••• 4421",
            avatarBg: Color(red: 1.00, green: 0.85, blue: 0.55),
            isFavorite: true,
            dateAdded: Date().addingTimeInterval(-86_400 * 30),
            phone: "504447421",
            phoneCode: "+971",
            email: "zoya.k@example.com",
            bankName: "Emirates NBD",
            iban: "AE070331234567890124421"
        ),
        Beneficiary(
            kind: .international,
            name: "Rayan Carter",
            nickname: nil,
            subtitle: "Barclays UK • GBP",
            avatarBg: Color(red: 0.66, green: 0.78, blue: 0.92),
            isFavorite: false,
            dateAdded: Date().addingTimeInterval(-86_400 * 90),
            phone: "7700908830",
            phoneCode: "+44",
            bankName: "Barclays UK",
            swift: "BARCGB22",
            accountNumber: "GB29NWBK60161331928830",
            country: "United Kingdom",
            currency: "GBP",
            address: "12 Queen St, London"
        )
    ]

    /// Inserts at the top so the freshly-added contact is the first thing the user sees.
    func add(_ b: Beneficiary) {
        items.insert(b, at: 0)
    }

    func remove(_ b: Beneficiary) {
        items.removeAll { $0.id == b.id }
    }

    func update(_ b: Beneficiary) {
        guard let idx = items.firstIndex(where: { $0.id == b.id }) else { return }
        items[idx] = b
    }

    func toggleFavorite(_ b: Beneficiary) {
        guard let idx = items.firstIndex(where: { $0.id == b.id }) else { return }
        items[idx].isFavorite.toggle()
    }
}
