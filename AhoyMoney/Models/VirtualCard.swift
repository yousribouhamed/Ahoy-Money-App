import Foundation
import SwiftUI

// MARK: - Card design catalogue

/// Visual treatments the user can pick when issuing a card.
/// Each design defines a gradient, an accent for the chip / type marks,
/// and the foreground (text) colour so we get good contrast on every variant.
enum CardDesign: String, CaseIterable, Hashable, Identifiable {
    case aurora         // cyan → navy (matches the app)
    case midnight       // pure black w/ blue glow
    case sunset         // orange → magenta
    case forest         // emerald → teal
    case roseGold       // peach → rose with metallic feel
    case carbon         // graphite gradient with subtle texture
    case ocean          // azure → indigo
    case glacier        // off-white → ice (light card)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aurora:    return "Aurora"
        case .midnight:  return "Midnight"
        case .sunset:    return "Sunset"
        case .forest:    return "Forest"
        case .roseGold:  return "Rose Gold"
        case .carbon:    return "Carbon"
        case .ocean:     return "Ocean"
        case .glacier:   return "Glacier"
        }
    }

    /// Two-stop gradient; goes top-leading → bottom-trailing for a soft diagonal sheen.
    var gradient: LinearGradient {
        let pair: (Color, Color) = {
            switch self {
            case .aurora:   return (Color(red: 0.06, green: 0.78, blue: 0.95), Color(red: 0.05, green: 0.16, blue: 0.42))
            case .midnight: return (Color(red: 0.05, green: 0.06, blue: 0.12), Color(red: 0.02, green: 0.02, blue: 0.06))
            case .sunset:   return (Color(red: 1.00, green: 0.51, blue: 0.32), Color(red: 0.88, green: 0.18, blue: 0.55))
            case .forest:   return (Color(red: 0.21, green: 0.78, blue: 0.55), Color(red: 0.04, green: 0.36, blue: 0.40))
            case .roseGold: return (Color(red: 1.00, green: 0.79, blue: 0.74), Color(red: 0.78, green: 0.39, blue: 0.42))
            case .carbon:   return (Color(red: 0.28, green: 0.30, blue: 0.34), Color(red: 0.08, green: 0.08, blue: 0.10))
            case .ocean:    return (Color(red: 0.18, green: 0.46, blue: 0.92), Color(red: 0.07, green: 0.13, blue: 0.45))
            case .glacier:  return (Color(red: 0.95, green: 0.97, blue: 1.00), Color(red: 0.80, green: 0.92, blue: 0.97))
            }
        }()
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Used to draw the chip and contactless glyph — matches each gradient's brightest stop.
    var accent: Color {
        switch self {
        case .aurora:    return Color(red: 0.74, green: 0.93, blue: 1.00)
        case .midnight:  return Color(red: 0.50, green: 0.65, blue: 1.00)
        case .sunset:    return Color(red: 1.00, green: 0.80, blue: 0.55)
        case .forest:    return Color(red: 0.74, green: 0.97, blue: 0.80)
        case .roseGold:  return Color(red: 0.99, green: 0.91, blue: 0.86)
        case .carbon:    return Color(red: 0.78, green: 0.80, blue: 0.84)
        case .ocean:     return Color(red: 0.74, green: 0.85, blue: 1.00)
        case .glacier:   return Color(red: 0.18, green: 0.55, blue: 0.78)
        }
    }

    /// Foreground (text + brand mark) colour with adequate contrast against the gradient.
    var foreground: Color {
        switch self {
        case .glacier: return Color(red: 0.07, green: 0.13, blue: 0.30)
        case .roseGold: return Color(red: 0.18, green: 0.06, blue: 0.10)
        default: return .white
        }
    }

    /// Soft shadow tint underneath the card on the wallet — matches the design's first stop.
    var shadowTint: Color {
        switch self {
        case .glacier:  return Color(red: 0.5, green: 0.7, blue: 0.9)
        case .midnight: return Color(red: 0.0, green: 0.0, blue: 0.2)
        default:
            // Pull the first colour of the gradient at low opacity.
            return gradient.shadowSeed
        }
    }

    /// Short tagline shown under the swatch on the design picker.
    var tagline: String {
        switch self {
        case .aurora:    return "Signature cyan"
        case .midnight:  return "Stealth black"
        case .sunset:    return "Warm gradient"
        case .forest:    return "Deep emerald"
        case .roseGold:  return "Soft metallic"
        case .carbon:    return "Industrial"
        case .ocean:     return "Deep blue"
        case .glacier:   return "Light & bright"
        }
    }
}

// MARK: - Internal helper

private extension LinearGradient {
    /// Best-effort tint — used for shadow underneath the card.
    /// Falls back to a soft cyan if the gradient isn't introspectable.
    var shadowSeed: Color {
        Color.black.opacity(0.5)
    }
}

// MARK: - Status

enum CardStatus: Hashable {
    case active
    case frozen
    case blocked
}

// MARK: - Card

/// A single issued virtual card.
struct VirtualCard: Identifiable, Hashable {
    let id: UUID
    var label: String                 // e.g. "Travel", "Subscriptions"
    var design: CardDesign
    var status: CardStatus
    var balance: Decimal              // available balance on this card
    var monthlyLimit: Decimal         // soft limit for visual progress bar
    var spentThisMonth: Decimal
    var last4: String                 // visible without reveal
    var fullNumber: String            // shown only after Face ID reveal
    var expiry: String                // e.g. "08/29"
    var cvv: String                   // shown only after Face ID reveal
    var cardholderName: String        // embossed on the card
    var issuedAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        design: CardDesign,
        status: CardStatus = .active,
        balance: Decimal,
        monthlyLimit: Decimal = 5000,
        spentThisMonth: Decimal = 0,
        last4: String,
        fullNumber: String,
        expiry: String,
        cvv: String,
        cardholderName: String,
        issuedAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.design = design
        self.status = status
        self.balance = balance
        self.monthlyLimit = monthlyLimit
        self.spentThisMonth = spentThisMonth
        self.last4 = last4
        self.fullNumber = fullNumber
        self.expiry = expiry
        self.cvv = cvv
        self.cardholderName = cardholderName
        self.issuedAt = issuedAt
    }

    /// Pretty grouped representation: "1234 5678 9012 3456" → unchanged but with single space groups.
    var formattedNumber: String {
        let digits = fullNumber.filter(\.isNumber)
        return stride(from: 0, to: digits.count, by: 4).map {
            let start = digits.index(digits.startIndex, offsetBy: $0)
            let end = digits.index(start, offsetBy: min(4, digits.count - $0))
            return String(digits[start..<end])
        }.joined(separator: " ")
    }
}

// MARK: - Store

/// Process-wide store of issued virtual cards. Seeded with one default card so
/// the wallet always has something to show on first run.
@Observable
final class VirtualCardStore {
    var cards: [VirtualCard] = [
        VirtualCard(
            label: "Everyday",
            design: .aurora,
            status: .active,
            balance: 1_250.50,
            monthlyLimit: 5_000,
            spentThisMonth: 1_320,
            last4: "4421",
            fullNumber: "4242 4242 4242 4421",
            expiry: "08/29",
            cvv: "342",
            cardholderName: "YOUSRI BOUHAMED"
        )
    ]

    /// Inserts at the top so the just-issued card is featured first.
    func add(_ card: VirtualCard) {
        cards.insert(card, at: 0)
    }

    func remove(_ card: VirtualCard) {
        cards.removeAll { $0.id == card.id }
    }

    func update(_ card: VirtualCard) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i] = card
    }

    func setStatus(_ card: VirtualCard, _ status: CardStatus) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i].status = status
    }

    func toggleFreeze(_ card: VirtualCard) {
        guard let i = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[i].status = (cards[i].status == .frozen) ? .active : .frozen
    }

    /// Generates a random-but-stable demo card. Real implementation would call the issuer API.
    static func makeMockCard(label: String, design: CardDesign, cardholderName: String) -> VirtualCard {
        let last4 = String(format: "%04d", Int.random(in: 1000...9999))
        let bin = "4242"
        let middle = "\(Int.random(in: 1000...9999)) \(Int.random(in: 1000...9999))"
        let full = "\(bin) \(middle) \(last4)"
        let cvv = String(format: "%03d", Int.random(in: 100...999))
        let year = Calendar.current.component(.year, from: Date()) % 100 + 5
        let month = Int.random(in: 1...12)
        let expiry = String(format: "%02d/%02d", month, year)
        return VirtualCard(
            label: label.isEmpty ? "Virtual card" : label,
            design: design,
            balance: 0,
            monthlyLimit: 5_000,
            spentThisMonth: 0,
            last4: last4,
            fullNumber: full,
            expiry: expiry,
            cvv: cvv,
            cardholderName: cardholderName.uppercased()
        )
    }
}
