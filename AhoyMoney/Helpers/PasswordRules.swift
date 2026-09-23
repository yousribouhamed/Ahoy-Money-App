import SwiftUI

/// The password rule, in one place.
///
/// Registration and any future reset flow have to agree on this — a rule that's
/// enforced in two places eventually gets enforced two different ways.
enum PasswordRules {
    static let minimumLength = 8

    /// Each requirement stated separately, so the customer can be told what's
    /// missing rather than just that the password is wrong.
    enum Requirement: String, CaseIterable, Identifiable {
        case length
        case letter
        case number
        case special

        var id: String { rawValue }

        var label: String {
            switch self {
            case .length:  return "At least \(minimumLength) characters"
            case .letter:  return "A letter"
            case .number:  return "A number"
            case .special: return "A special character, like ! or #"
            }
        }

        func isMet(by password: String) -> Bool {
            switch self {
            case .length:
                return password.count >= minimumLength
            case .letter:
                return password.contains(where: \.isLetter)
            case .number:
                return password.contains(where: \.isNumber)
            case .special:
                // Anything that isn't a letter, a number or whitespace.
                return password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
            }
        }
    }

    static func unmet(in password: String) -> [Requirement] {
        Requirement.allCases.filter { !$0.isMet(by: password) }
    }

    static func isValid(_ password: String) -> Bool {
        unmet(in: password).isEmpty
    }
}

// MARK: - Checklist

/// Live requirement list shown under the password field.
///
/// Always visible rather than appearing on error: someone should be able to
/// meet the rule on the first attempt instead of discovering it by failing.
struct PasswordRequirementList: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(PasswordRules.Requirement.allCases) { requirement in
                let met = requirement.isMet(by: password)
                HStack(spacing: 8) {
                    Image(systemName: met ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(met ? Theme.accent : Theme.textSecondary)
                    Text(requirement.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(met ? Theme.textPrimary : Theme.textSecondary)
                }
                .animation(.easeOut(duration: 0.15), value: met)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
