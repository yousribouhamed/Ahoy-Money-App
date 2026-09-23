import Foundation
import SwiftUI

// MARK: - Employer

struct Employer: Identifiable, Hashable {
    let id: String
    let name: String
    /// Shown under the name in search results to separate similar employers.
    var trade: String?

    init(id: String = UUID().uuidString, name: String, trade: String? = nil) {
        self.id = id
        self.name = name
        self.trade = trade
    }
}

/// Where the employer list comes from.
///
/// Behind a protocol because it's unconfirmed whether a real directory endpoint
/// exists yet — swapping the local list for an API is then a one-type change
/// rather than a screen rewrite.
protocol EmployerDirectory {
    func search(_ query: String) async -> [Employer]
}

/// Stand-in directory until the endpoint is confirmed.
struct LocalEmployerDirectory: EmployerDirectory {
    static let sample: [Employer] = [
        Employer(name: "Emirates Facilities Management", trade: "Facilities"),
        Employer(name: "Al Futtaim Group", trade: "Retail & automotive"),
        Employer(name: "Dulsco Group", trade: "Workforce solutions"),
        Employer(name: "Transguard Group", trade: "Security & logistics"),
        Employer(name: "Emrill Services", trade: "Facilities"),
        Employer(name: "Imdaad", trade: "Facilities"),
        Employer(name: "ServeU", trade: "Facilities"),
        Employer(name: "Khansaheb", trade: "Construction")
    ]

    var employers: [Employer] = sample

    func search(_ query: String) async -> [Employer] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return employers }
        return employers.filter { $0.name.lowercased().contains(q) }
    }
}

// MARK: - Enrolment path

/// How the customer reached onboarding.
///
/// Two paths through one container: a worker invited by an employer, and a
/// person who signs up on their own. The employer is known on the first and
/// unknown on the second, and that is the only difference the form cares about.
enum EnrolmentPath: Hashable {
    case invited(employer: Employer)
    case standalone

    var employer: Employer? {
        if case let .invited(employer) = self { return employer }
        return nil
    }
}

// MARK: - Invite

/// Resolves an employer invite.
///
/// **Placeholder.** How an invited worker actually arrives isn't confirmed —
/// most likely a deep link from an invite message, possibly a code they type.
/// This models the code because it's the version that can be demonstrated
/// without a backend; a deep link would call the same resolve step.
/// What a code turned out to be.
///
/// Three cases rather than an `Employer?`. A code that doesn't exist and a real
/// code that has run out need opposite recoveries — retype it versus go back to
/// your employer — and an optional collapses both into the same `nil`. That's
/// how they ended up sharing one "we don't recognise that code" message, which
/// is actively wrong for an expired code: we *do* recognise it.
enum InviteOutcome {
    case valid(Employer)

    /// A real code, past its window.
    ///
    /// `employer` is whoever issued it, where that's still known — without it a
    /// screen can say the door is shut but not who holds the key. `on` is when
    /// it lapsed. **How long a code lasts isn't settled**, so this carries a
    /// date rather than a duration and no copy anywhere states a number of days.
    case expired(employer: Employer?, on: Date?)

    /// No such code. Nearly always a typo.
    case unrecognised
}

protocol InviteResolver {
    func resolve(code: String) async -> InviteOutcome
}

struct LocalInviteResolver: InviteResolver {
    /// Demo behaviour, so all three outcomes are walkable without a backend:
    ///
    /// - `EXPIRED…` → expired, attributed and dated
    /// - `AHOY…` → valid; the suffix picks the employer
    /// - anything else → unrecognised
    func resolve(code: String) async -> InviteOutcome {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count >= 4 else { return .unrecognised }

        // Checked before the AHOY prefix so an expired demo code can still look
        // like a real one.
        if trimmed.hasPrefix("EXPIRED") {
            return .expired(
                employer: LocalEmployerDirectory.sample.first,
                on: Calendar.current.date(byAdding: .day, value: -9, to: Date())
            )
        }

        guard trimmed.hasPrefix("AHOY") else { return .unrecognised }
        let index = abs(trimmed.hashValue) % LocalEmployerDirectory.sample.count
        return .valid(LocalEmployerDirectory.sample[index])
    }
}

// MARK: - Checklist

/// The two things the last step of onboarding asks for. Both are mandatory,
/// neither can stop the customer, and either can be deferred with "Do it later".
enum ChecklistItem: String, CaseIterable, Hashable, Identifiable {
    case email
    case proofOfAddress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .email:          return "Verify your email"
        case .proofOfAddress: return "Upload proof of address"
        }
    }

    var detail: String {
        switch self {
        case .email:          return "We'll send a 6-digit code to the address you gave us."
        case .proofOfAddress: return "A bill or tenancy contract showing the address you entered."
        }
    }

    var icon: String {
        switch self {
        case .email:          return "envelope"
        case .proofOfAddress: return "doc.text"
        }
    }
}

/// What a reviewer asked for, in their own words.
///
/// An open request is **not a status** — the customer is still under review,
/// not rejected — so this hangs off the review rather than replacing it.
struct InfoRequest: Hashable {
    /// The reviewer's reason, written by them. Not a template.
    var note: String
    var items: [RequestedItem]
    var askedOn: Date = Date()
}

/// Something Compliance has come back and asked for.
struct RequestedItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String?

    /// Files the customer has attached against this item.
    ///
    /// A list, not a single file: "three months of statements" is one request
    /// and three documents, and the reviewer has no way to split it into three
    /// asks.
    var files: [String] = []

    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        files: [String] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.files = files
    }

    /// The only guidance that's ours rather than the reviewer's. What the
    /// document must *contain* comes from their note — they type it in free
    /// text and there's no field for us to structure it into.
    static let fileGuidance = "A PDF or a clear photo, with the whole document in frame."

}

// MARK: - Why a file is in review

/// Two ways into the waiting screen, and they need different words.
///
/// A customer who corrected a misread name did the right thing and is waiting
/// *because* of it. Telling them we're reviewing their details is true, but it
/// reads as suspicion — so the edit route says what actually happened.
enum ReviewReason: Hashable {
    /// Something in the file needs a person to look at it.
    case riskFactor
    /// They changed one of the fields read off their Emirates ID.
    case editedDetails

    var title: String {
        switch self {
        case .riskFactor:    return "We're checking a few things"
        case .editedDetails: return "Thanks — we're checking your changes"
        }
    }

    var detail: String {
        switch self {
        case .riskFactor:
            return "Someone on our team needs to look at your application before we can open your wallet. It's a routine check and most are done well within a day."
        case .editedDetails:
            return "You corrected something we read off your Emirates ID, so a person needs to confirm it against your document. That's the only reason this is taking a little longer."
        }
    }
}

// MARK: - The seven states

/// Where a customer is in onboarding.
///
/// Several cases carry payload the screens need — an attempt count, what's
/// outstanding, when review started — so this can't collapse to a flag.
enum OnboardingState: Hashable {
    /// Account exists, identity not done yet.
    case registered
    /// uqudo couldn't verify them. Retryable until attempts run out.
    case identityFailed(attemptsUsed: Int, canRetry: Bool)
    /// Deferred the email, the address document, or both. The file has **not**
    /// reached Compliance — that's the whole point of this state.
    case profileIncomplete(outstanding: [ChecklistItem])
    /// Complete file, with Compliance, waiting on a human.
    case underReview(since: Date, reason: ReviewReason, request: InfoRequest?)
    /// An automatic control stopped it. No queue, no reviewer — and a timer
    /// before they can try again.
    case systemRefused(retryFrom: Date)
    case approved
    /// A person decided and wrote a reason that cannot be shared. Not quite
    /// terminal — they may reapply once the wait is up.
    case rejected(reapplyFrom: Date)
}

/// What uqudo came back with.
enum IdentityOutcome: Hashable {
    case notStarted
    case passed
    case failed(attempts: Int)
}

/// What Compliance came back with. Absent until the file is submitted.
enum ComplianceDecision: Hashable {
    /// `request` is set when a reviewer has asked for something. The customer
    /// is still under review either way.
    case underReview(since: Date, reason: ReviewReason, request: InfoRequest?)
    case approved
    /// A person decided. The reason exists but cannot be shared.
    case rejected(reapplyFrom: Date)
}

/// An automatic control — an expired or unreadable document, a sanctions match,
/// a prohibited jurisdiction. Kept apart from `ComplianceDecision` because no
/// person was involved and no queue exists.
struct SystemRefusal: Hashable {
    var retryFrom: Date

    /// The wait before another attempt is allowed.
    static let cooldown: TimeInterval = 30 * 60
}

// MARK: - Store

/// Owns where a customer is in onboarding.
///
/// **Why facts rather than a single stored state.** It's still open whether a
/// customer can be in two states at once — identity failed *and* profile
/// incomplete, say. So the underlying facts are stored independently and
/// `displayState` resolves them into the one state a screen should render. If
/// the answer is "one at a time", nothing here changes. If it's "they overlap",
/// the priority order below is already the only thing to revisit.
@Observable
final class OnboardingStore {

    // MARK: Facts

    /// Unknown until the customer either enters an invite code or declines to.
    var enrolmentPath: EnrolmentPath? = nil

    /// Phone confirmed by OTP — the first thing that's true about a customer.
    var phoneVerified: Bool = false

    var identityOutcome: IdentityOutcome = .notStarted

    /// What's still owed. Empty means the profile is complete.
    var outstanding: Set<ChecklistItem> = Set(ChecklistItem.allCases)

    /// Absent until the file is submitted — a customer who hasn't been sent to
    /// Compliance has no decision, rather than a pending one.
    var complianceDecision: ComplianceDecision? = nil

    /// Set when an automatic control stops the application.
    var systemRefusal: SystemRefusal? = nil

    var invites: InviteResolver = LocalInviteResolver()

    /// Swapped for an APNs-backed type when push exists. See `ReviewNotifier`.
    var notifier: ReviewNotifier = LocalReviewNotifier()

    /// Read off the Emirates ID by the identity check, then checked by the
    /// customer on Fill Details.
    var identity: IdentityDetails = .scannedSample

    // MARK: Wallet and card — two switches, not one
    //
    // Card issuance carries its own mandatory information and document set, so
    // an open wallet is not proof a card can be issued. On a clean file both
    // land together and look like one event; the code shouldn't assume that.

    var walletOpen: Bool = false
    var cardIssued: Bool = false

    /// How many identity attempts before a person looks at it. Provisional —
    /// the number is the PO's, so it lives here rather than in a screen.
    var maxIdentityAttempts: Int = 3

    // MARK: Derived

    var resolvedPath: EnrolmentPath { enrolmentPath ?? .standalone }
    var isInvited: Bool { enrolmentPath?.employer != nil }

    /// Outstanding items in a stable order, so the checklist doesn't reshuffle.
    var outstandingItems: [ChecklistItem] {
        ChecklistItem.allCases.filter { outstanding.contains($0) }
    }

    var profileComplete: Bool { outstanding.isEmpty }

    /// The one state to render.
    ///
    /// Order matters: a terminal decision outranks everything, then anything
    /// Compliance is waiting on, then anything the customer still owes, then
    /// identity, then plain registered.
    var displayState: OnboardingState {
        // An automatic control outranks everything — no person is involved and
        // there's nothing queued behind it.
        if let refusal = systemRefusal {
            return .systemRefused(retryFrom: refusal.retryFrom)
        }

        switch complianceDecision {
        case let .rejected(reapplyFrom):           return .rejected(reapplyFrom: reapplyFrom)
        case .approved:                            return .approved
        case let .underReview(since, reason, req): return .underReview(since: since, reason: reason, request: req)
        case nil:                                  break
        }

        if case let .failed(attempts) = identityOutcome {
            return .identityFailed(
                attemptsUsed: attempts,
                canRetry: attempts < maxIdentityAttempts
            )
        }

        if !profileComplete { return .profileIncomplete(outstanding: outstandingItems) }

        return .registered
    }

    /// True only once Compliance has approved. This is what a card gate would
    /// hang off — nothing else in the app should infer approval.
    var isApproved: Bool {
        if case .approved = complianceDecision { return true }
        return false
    }

    // MARK: Transitions

    func applyInvite(_ employer: Employer) { enrolmentPath = .invited(employer: employer) }
    func useStandalonePath() { enrolmentPath = .standalone }

    /// Email and proof of address are optional and live in the app. Completing
    /// one changes nothing else — neither blocks the wallet, the card, or the
    /// Compliance decision.
    func complete(_ item: ChecklistItem) {
        outstanding.remove(item)
    }

    func deferAll() {
        // "Do it later" ends the journey and opens the app. Nothing is sent.
    }

    /// True once the file has been handed to a person — set by `sendToReview`
    /// and read by the journey to decide where the passcode step lands.
    var isHeldForReview: Bool {
        if case .underReview = complianceDecision { return true }
        return false
    }

    /// Sends the file to Compliance.
    ///
    /// This used to require an empty checklist. It no longer does: email and
    /// proof of address are optional in-app items and don't gate the decision.
    /// The only guard left is not submitting twice.
    /// Most customers never call this — they're approved instantly and the
    /// wallet and card open together. Review is the exception, reached only by
    /// a risk factor or by the customer editing an ID-read field.
    @discardableResult
    func sendToReview(_ reason: ReviewReason) -> Bool {
        guard complianceDecision == nil else { return false }
        complianceDecision = .underReview(since: Date(), reason: reason, request: nil)
        // Asked here rather than at launch: this is the one moment the customer
        // has a reason to say yes, because we've just told them we'll let them
        // know. A prompt on the splash screen is the one people decline.
        Task { [notifier] in await notifier.requestPermission() }
        return true
    }

    /// The common path: approved on the spot.
    ///
    /// A clean file opens the wallet and issues the card in the same moment,
    /// which is why they read as a single event. They are still two switches —
    /// see `cardIssued`.
    func approveInstantly(cardCanBeIssued: Bool = true) {
        complianceDecision = .approved
        walletOpen = true
        cardIssued = cardCanBeIssued
    }

    /// Nothing is issued while a file is in review — no wallet, no card.
    var isAwaitingReview: Bool {
        if case .underReview = complianceDecision { return true }
        return false
    }

    /// The stated turnaround, from when the file was complete.
    static let reviewWindowHours = 24

    // Back-office outcomes, for driving the states in a prototype.

    func complianceApproved() {
        let wasWaiting = isAwaitingReview
        complianceDecision = .approved
        walletOpen = true
        cardIssued = true
        // Only notify someone who was actually kept waiting. An instant
        // approval never showed them the promise, so a push would arrive out
        // of nowhere.
        if wasWaiting {
            Task { [notifier] in await notifier.reviewCleared(approved: true) }
        }
    }

    func complianceRejected() {
        let wasWaiting = isAwaitingReview
        complianceDecision = .rejected(reapplyFrom: Date().addingTimeInterval(SystemRefusal.cooldown))
        if wasWaiting {
            Task { [notifier] in await notifier.reviewCleared(approved: false) }
        }
    }

    /// A reviewer asking for something keeps the file under review.
    func complianceRequests(_ request: InfoRequest) {
        guard case let .underReview(since, reason, _) = complianceDecision else { return }
        complianceDecision = .underReview(since: since, reason: reason, request: request)
    }

    /// An automatic control stopped it. Thirty minutes, then they can retry.
    func systemRefuse() {
        systemRefusal = SystemRefusal(retryFrom: Date().addingTimeInterval(SystemRefusal.cooldown))
    }

    func clearSystemRefusal() { systemRefusal = nil }

    func identityFailed() {
        let used: Int
        if case let .failed(attempts) = identityOutcome { used = attempts + 1 } else { used = 1 }
        identityOutcome = .failed(attempts: used)
    }

    func identityPassed() { identityOutcome = .passed }

    /// Back to the start of identity after a failure.
    func retryIdentity() {
        if case .failed = identityOutcome { identityOutcome = .notStarted }
    }
}

// MARK: - Identity details

/// The Fill Details header block.
///
/// Five of these were read off the Emirates ID by the identity check, so the
/// screen shows what it read and asks the customer to check it. Two are typed,
/// because they aren't on the card.
///
/// **Editing a read field is the branch.** A card that scanned badly must not
/// strand a real customer, so edits are allowed — but an edited field is no
/// longer what the document said, so it sends them to manual review. That makes
/// this screen's two exits: confirm and go instantly, or edit and wait.
struct IdentityDetails {

    enum Field: String, CaseIterable, Identifiable {
        // Read from the card. `idExpiry` sits with the number it belongs to:
        // an expired document can't be relied on, so Compliance needs the date
        // on file alongside everything else the card said.
        case fullName, dateOfBirth, nationality, emiratesID, idExpiry
        // Typed — not on the Emirates ID.
        case placeOfBirth, passportNumber

        var id: String { rawValue }

        /// True for the four the identity check read off the card.
        var isReadFromCard: Bool {
            switch self {
            case .fullName, .dateOfBirth, .nationality, .emiratesID, .idExpiry: return true
            case .placeOfBirth, .passportNumber: return false
            }
        }

        var label: String {
            switch self {
            case .fullName:       return "Full name"
            case .dateOfBirth:    return "Date of birth"
            case .nationality:    return "Nationality"
            case .emiratesID:     return "Emirates ID number"
            case .idExpiry:       return "Emirates ID expiry date"
            case .placeOfBirth:   return "Place of birth"
            case .passportNumber: return "Passport number"
            }
        }

        /// Why we're asking, for the two that aren't on the card.
        var helper: String? {
            switch self {
            case .placeOfBirth:   return "This isn't on your Emirates ID, so we need you to add it."
            case .passportNumber: return "We don't photograph your passport — just the number."
            default:              return nil
            }
        }

        var placeholder: String {
            switch self {
            case .placeOfBirth:   return "City and country"
            case .passportNumber: return "As printed on your passport"
            default:              return ""
            }
        }
    }

    /// What the card said. Kept so an edit can be detected and shown.
    private(set) var scanned: [Field: String]
    var values: [Field: String]

    init(scanned: [Field: String]) {
        self.scanned = scanned
        // Typed fields start empty; read fields start at what was scanned.
        var v = scanned
        for field in Field.allCases where !field.isReadFromCard {
            v[field] = v[field] ?? ""
        }
        self.values = v
    }

    func value(_ field: Field) -> String { values[field] ?? "" }

    /// A read field that no longer matches the card.
    func wasEdited(_ field: Field) -> Bool {
        guard field.isReadFromCard else { return false }
        return (values[field] ?? "") != (scanned[field] ?? "")
    }

    var editedFields: [Field] {
        Field.allCases.filter { wasEdited($0) }
    }

    /// The branch. Any edit to a read field means a person has to confirm it.
    var needsManualReview: Bool { !editedFields.isEmpty }

    var isComplete: Bool {
        Field.allCases.allSatisfy { !value($0).trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Stand-in for what the identity check returns.
    static var scannedSample: IdentityDetails {
        IdentityDetails(scanned: [
            .fullName:    "YOUSRI BOUHAMED",
            .dateOfBirth: "07/11/1994",
            .nationality: "Algeria",
            .emiratesID:  "784-1994-1234567-1",
            .idExpiry:    "12/03/2027"
        ])
    }
}
