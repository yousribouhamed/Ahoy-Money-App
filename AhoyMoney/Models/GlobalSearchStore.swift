import Foundation
import SwiftUI

/// Process-wide store for the home global search.
///
/// Keeps the recent-search history (capped at 8) and a curated list of
/// "trending" topics — same pattern Revolut / Wise / Cash App use to bootstrap
/// the empty state with content.
@Observable
final class GlobalSearchStore {
    var recentSearches: [String] = []

    /// Hand-picked discoverable terms — shown when the search field is empty.
    /// Mix of people-y, money-y, and product terms so first-time users get
    /// a feel for what's searchable.
    let trending: [String] = [
        "Mia", "Rent", "Travel", "Subscriptions",
        "Top up", "Freeze card", "Schedule", "Help"
    ]

    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 2 else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 8 {
            recentSearches = Array(recentSearches.prefix(8))
        }
    }

    func clearRecents() {
        recentSearches.removeAll()
    }
}

// MARK: - Mock transaction model

/// Lightweight transactions model the global search can search across.
/// Real apps would back this with a server-side index — here we seed enough
/// rows to make the search feel populated.
struct MockTransaction: Identifiable, Hashable {
    let id: UUID
    let title: String
    let merchant: String
    let category: String
    let amount: Decimal
    let isCredit: Bool
    let date: Date
    let icon: String

    init(
        id: UUID = UUID(),
        title: String,
        merchant: String,
        category: String,
        amount: Decimal,
        isCredit: Bool,
        date: Date,
        icon: String
    ) {
        self.id = id
        self.title = title
        self.merchant = merchant
        self.category = category
        self.amount = amount
        self.isCredit = isCredit
        self.date = date
        self.icon = icon
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

@Observable
final class TransactionStore {
    var items: [MockTransaction] = []

    /// Empty by default — a new account has no history, and the dashboard's
    /// empty state has to be the truthful default rather than something you
    /// only see if you delete things.
    ///
    /// Global Search reads the same list, so searching a new account correctly
    /// finds nothing. `loadDemoData()` fills it for demos; see the Debug
    /// section in Settings.
    init() {}

    func loadDemoData() { seed() }

    func clear() { items = [] }

    func search(_ query: String) -> [MockTransaction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return items
            .filter {
                $0.title.lowercased().contains(q)
                || $0.merchant.lowercased().contains(q)
                || $0.category.lowercased().contains(q)
            }
            .sorted { $0.date > $1.date }
    }

    private func seed() {
        let cal = Calendar.current
        let day: (Int) -> Date = { cal.date(byAdding: .day, value: -$0, to: Date()) ?? Date() }

        items = [
            .init(title: "Grocery run",   merchant: "Carrefour",  category: "Groceries",     amount: 142.30, isCredit: false, date: day(1),  icon: "cart.fill"),
            .init(title: "Netflix",       merchant: "Netflix",    category: "Subscriptions", amount: 39.00,  isCredit: false, date: day(2),  icon: "play.rectangle.fill"),
            .init(title: "Salary",        merchant: "Acme Corp",  category: "Income",        amount: 12_500, isCredit: true,  date: day(3),  icon: "arrow.down.circle.fill"),
            .init(title: "Coffee",        merchant: "Starbucks",  category: "Food & Drink",  amount: 22.50,  isCredit: false, date: day(3),  icon: "cup.and.saucer.fill"),
            .init(title: "Cash-out",      merchant: "Ahoy",       category: "Transfer",      amount: 800,    isCredit: false, date: day(4),  icon: "arrow.right.circle.fill"),
            .init(title: "Uber",          merchant: "Uber",       category: "Transport",     amount: 48.00,  isCredit: false, date: day(5),  icon: "car.fill"),
            .init(title: "Gym",           merchant: "FitX",       category: "Health",        amount: 250,    isCredit: false, date: day(7),  icon: "figure.run"),
            .init(title: "Refund",        merchant: "Amazon",     category: "Refund",        amount: 89.00,  isCredit: true,  date: day(8),  icon: "arrow.uturn.backward.circle.fill"),
            .init(title: "Rent",          merchant: "Property Co",category: "Housing",       amount: 4_500,  isCredit: false, date: day(10), icon: "house.fill"),
            .init(title: "Dinner",        merchant: "Sushi Bar",  category: "Food & Drink",  amount: 187.00, isCredit: false, date: day(11), icon: "fork.knife"),
            .init(title: "Spotify",       merchant: "Spotify",    category: "Subscriptions", amount: 21.99,  isCredit: false, date: day(13), icon: "music.note"),
            .init(title: "Travel ticket", merchant: "Emirates",   category: "Travel",        amount: 1_840,  isCredit: false, date: day(14), icon: "airplane"),
        ]
    }
}
