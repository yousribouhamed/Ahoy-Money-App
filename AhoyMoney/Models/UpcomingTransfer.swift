import Foundation
import SwiftUI

// MARK: - Frequency

/// How often the scheduled transfer fires.
///
/// Modeled after Revolut / Wise / Monzo: a fixed enum with a single human-
/// readable label per case. Each case knows how to advance a date by one tick,
/// so the store can compute `nextDate` after a successful execution without
/// any extra calendar plumbing in the views.
enum TransferFrequency: String, CaseIterable, Identifiable, Codable, Hashable {
    case once
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once:      return "One-time"
        case .weekly:    return "Weekly"
        case .biweekly:  return "Every 2 weeks"
        case .monthly:   return "Monthly"
        case .quarterly: return "Every 3 months"
        case .yearly:    return "Yearly"
        }
    }

    /// Short pill label used inside list rows (`Weekly`, `Monthly`, `Once`…).
    var shortName: String {
        switch self {
        case .once:      return "Once"
        case .weekly:    return "Weekly"
        case .biweekly:  return "Bi-weekly"
        case .monthly:   return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly:    return "Yearly"
        }
    }

    var icon: String {
        switch self {
        case .once:      return "calendar"
        case .weekly:    return "arrow.triangle.2.circlepath"
        case .biweekly:  return "arrow.triangle.2.circlepath"
        case .monthly:   return "calendar.badge.clock"
        case .quarterly: return "calendar.badge.clock"
        case .yearly:    return "calendar.circle"
        }
    }

    /// Returns the date of the *next* occurrence after `from`.
    func advance(from date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .once:      return date
        case .weekly:    return cal.date(byAdding: .day,   value: 7,  to: date) ?? date
        case .biweekly:  return cal.date(byAdding: .day,   value: 14, to: date) ?? date
        case .monthly:   return cal.date(byAdding: .month, value: 1,  to: date) ?? date
        case .quarterly: return cal.date(byAdding: .month, value: 3,  to: date) ?? date
        case .yearly:    return cal.date(byAdding: .year,  value: 1,  to: date) ?? date
        }
    }
}

// MARK: - End rule

/// When does a recurring schedule stop? (Wise / N26 model.)
enum TransferEndRule: Hashable, Codable {
    case never
    case onDate(Date)
    case afterOccurrences(Int)

    var displayName: String {
        switch self {
        case .never:                   return "Until I cancel"
        case .onDate(let d):            return "Until \(Self.df.string(from: d))"
        case .afterOccurrences(let n):  return "After \(n) payment\(n == 1 ? "" : "s")"
        }
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}

// MARK: - Status

enum UpcomingTransferStatus: String, Codable, Hashable {
    case active
    case paused
    case completed
    case failed
}

// MARK: - History

/// A past execution of the schedule — drives the timeline on the detail view.
struct TransferHistoryEntry: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let amount: Decimal
    let status: UpcomingTransferStatus
    let note: String?

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Decimal,
        status: UpcomingTransferStatus,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.status = status
        self.note = note
    }
}

// MARK: - Model

/// A scheduled (one-time or recurring) outgoing transfer.
///
/// Stored separately from `Beneficiary` so the directory and the schedule
/// are independent — deleting a beneficiary won't auto-cancel a schedule, the
/// user is prompted instead. We reference the recipient by `beneficiaryId`
/// and resolve at view-time through `BeneficiaryStore`.
struct UpcomingTransfer: Identifiable, Hashable {
    let id: UUID
    var beneficiaryId: UUID
    var amount: Decimal
    var currency: String              // "AED", "USD", …
    var frequency: TransferFrequency
    var startDate: Date
    var nextDate: Date
    var endRule: TransferEndRule
    var status: UpcomingTransferStatus
    var note: String?
    var createdAt: Date
    var sourceLabel: String           // "Ahoy Wallet"
    var totalOccurrences: Int         // 0 if never-ending
    var completedOccurrences: Int
    var history: [TransferHistoryEntry]

    init(
        id: UUID = UUID(),
        beneficiaryId: UUID,
        amount: Decimal,
        currency: String = "AED",
        frequency: TransferFrequency,
        startDate: Date,
        nextDate: Date? = nil,
        endRule: TransferEndRule = .never,
        status: UpcomingTransferStatus = .active,
        note: String? = nil,
        createdAt: Date = Date(),
        sourceLabel: String = "Ahoy Wallet",
        totalOccurrences: Int = 0,
        completedOccurrences: Int = 0,
        history: [TransferHistoryEntry] = []
    ) {
        self.id = id
        self.beneficiaryId = beneficiaryId
        self.amount = amount
        self.currency = currency
        self.frequency = frequency
        self.startDate = startDate
        self.nextDate = nextDate ?? startDate
        self.endRule = endRule
        self.status = status
        self.note = note
        self.createdAt = createdAt
        self.sourceLabel = sourceLabel
        self.totalOccurrences = totalOccurrences
        self.completedOccurrences = completedOccurrences
        self.history = history
    }

    /// Days from now until next execution. Negative if overdue.
    var daysUntilNext: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.startOfDay(for: nextDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Friendly relative label for the row ("Tomorrow", "in 3 days", "Today")
    var nextRelative: String {
        let d = daysUntilNext
        switch d {
        case ..<0:  return "Overdue"
        case 0:     return "Today"
        case 1:     return "Tomorrow"
        case 2...6: return "in \(d) days"
        default:    return Self.shortDateFormatter.string(from: nextDate)
        }
    }

    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    static func format(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

// MARK: - Store

/// Process-wide store for scheduled transfers.
///
/// Seeded with five demo schedules spanning all rails (wallet / UAE / international)
/// so the list has interesting content — including one paused, one near-due,
/// one with a finite end date — to exercise every UI state.
@Observable
final class UpcomingTransferStore {
    var items: [UpcomingTransfer] = []

    init() {
        seed()
    }

    // MARK: Mutations

    func add(_ t: UpcomingTransfer) {
        items.insert(t, at: 0)
    }

    func update(_ t: UpcomingTransfer) {
        guard let idx = items.firstIndex(where: { $0.id == t.id }) else { return }
        items[idx] = t
    }

    func remove(_ t: UpcomingTransfer) {
        items.removeAll { $0.id == t.id }
    }

    func pause(_ t: UpcomingTransfer) {
        guard let idx = items.firstIndex(where: { $0.id == t.id }) else { return }
        items[idx].status = .paused
    }

    func resume(_ t: UpcomingTransfer) {
        guard let idx = items.firstIndex(where: { $0.id == t.id }) else { return }
        items[idx].status = .active
    }

    /// Skips the next execution — advances `nextDate` by one frequency tick
    /// without recording history. Mirrors Monzo's "Skip next payment".
    func skipNext(_ t: UpcomingTransfer) {
        guard let idx = items.firstIndex(where: { $0.id == t.id }) else { return }
        let current = items[idx]
        guard current.frequency != .once else { return }
        items[idx].nextDate = current.frequency.advance(from: current.nextDate)
    }

    // MARK: Derived helpers

    /// Filtered + sorted by `nextDate`. The list view uses this directly.
    func filtered(by filter: UpcomingFilter) -> [UpcomingTransfer] {
        return items
            .filter { t in
                switch filter {
                case .all:       return true
                case .active:    return t.status == .active
                case .paused:    return t.status == .paused
                case .completed: return t.status == .completed
                }
            }
            .sorted { a, b in
                // Active items show next-due first; completed sort newest first.
                if a.status == .completed && b.status == .completed {
                    return a.nextDate > b.nextDate
                }
                return a.nextDate < b.nextDate
            }
    }

    var nextUpcoming: UpcomingTransfer? {
        items
            .filter { $0.status == .active }
            .sorted { $0.nextDate < $1.nextDate }
            .first
    }

    /// Total amount scheduled this calendar month (all currencies summed
    /// naïvely — a real app would convert; for the demo it's directional).
    func amountThisMonth() -> Decimal {
        let cal = Calendar.current
        let now = Date()
        return items
            .filter { $0.status == .active }
            .filter { cal.isDate($0.nextDate, equalTo: now, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    // MARK: Seed

    private func seed() {
        // Pull beneficiary IDs from the canonical store at runtime — but we
        // don't have that here yet. Use stable mock IDs that the views can
        // resolve by index/name fallback.
        // To keep things simple, we generate fresh UUIDs here and the views
        // gracefully handle a nil beneficiary lookup.
        let cal = Calendar.current
        let day: (Int) -> Date = { cal.date(byAdding: .day, value: $0, to: Date()) ?? Date() }

        items = [
            UpcomingTransfer(
                beneficiaryId: UUID(),
                amount: 1500,
                currency: "AED",
                frequency: .monthly,
                startDate: day(-60),
                nextDate: day(2),
                endRule: .never,
                note: "Rent share",
                totalOccurrences: 0,
                completedOccurrences: 6,
                history: (1...6).map { i in
                    TransferHistoryEntry(
                        date: cal.date(byAdding: .month, value: -i, to: Date()) ?? Date(),
                        amount: 1500,
                        status: .completed
                    )
                }
            ),
            UpcomingTransfer(
                beneficiaryId: UUID(),
                amount: 250,
                currency: "AED",
                frequency: .weekly,
                startDate: day(-21),
                nextDate: day(4),
                endRule: .afterOccurrences(12),
                note: "Allowance",
                totalOccurrences: 12,
                completedOccurrences: 3,
                history: (1...3).map { i in
                    TransferHistoryEntry(
                        date: cal.date(byAdding: .day, value: -7 * i, to: Date()) ?? Date(),
                        amount: 250,
                        status: .completed
                    )
                }
            ),
            UpcomingTransfer(
                beneficiaryId: UUID(),
                amount: 75,
                currency: "GBP",
                frequency: .monthly,
                startDate: day(-90),
                nextDate: day(11),
                endRule: .never,
                status: .paused,
                note: "Subscription split",
                totalOccurrences: 0,
                completedOccurrences: 3
            ),
            UpcomingTransfer(
                beneficiaryId: UUID(),
                amount: 5000,
                currency: "AED",
                frequency: .once,
                startDate: day(20),
                nextDate: day(20),
                endRule: .afterOccurrences(1),
                note: "Birthday gift",
                totalOccurrences: 1,
                completedOccurrences: 0
            ),
            UpcomingTransfer(
                beneficiaryId: UUID(),
                amount: 320,
                currency: "AED",
                frequency: .monthly,
                startDate: day(-365),
                nextDate: day(-2),
                endRule: .afterOccurrences(12),
                status: .completed,
                note: "Payback complete",
                totalOccurrences: 12,
                completedOccurrences: 12
            )
        ]
    }
}

// MARK: - Filter

enum UpcomingFilter: Hashable, CaseIterable {
    case all, active, paused, completed
    var label: String {
        switch self {
        case .all:       return "All"
        case .active:    return "Active"
        case .paused:    return "Paused"
        case .completed: return "Completed"
        }
    }
}
