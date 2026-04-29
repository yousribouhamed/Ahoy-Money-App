import SwiftUI

/// Light bottom sheet for editing a saved beneficiary's nickname and favorite state.
///
/// Heavier edits (changing the underlying phone, IBAN, etc.) intentionally aren't
/// allowed here — those should require re-verification. For now the sheet covers
/// the 95% case: rename and pin/unpin.
struct EditBeneficiarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let beneficiary: Beneficiary
    var onSave: (Beneficiary) -> Void = { _ in }

    @State private var nickname: String
    @State private var isFavorite: Bool
    @FocusState private var nicknameFocused: Bool

    init(beneficiary: Beneficiary, onSave: @escaping (Beneficiary) -> Void = { _ in }) {
        self.beneficiary = beneficiary
        self.onSave = onSave
        _nickname = State(initialValue: beneficiary.nickname ?? "")
        _isFavorite = State(initialValue: beneficiary.isFavorite)
    }

    private var hasChanges: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = (beneficiary.nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed != original || isFavorite != beneficiary.isFavorite
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Edit beneficiary")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Update how \(beneficiary.name) appears in your list. Bank and contact details can't be changed — add a new beneficiary instead.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Nickname.
            VStack(alignment: .leading, spacing: 6) {
                Text("Nickname")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.grayText)

                TextField(
                    "",
                    text: $nickname,
                    prompt: Text("e.g. Mom, Best friend").foregroundStyle(Theme.grayText)
                )
                .focused($nicknameFocused)
                .submitLabel(.done)
                .onSubmit { nicknameFocused = false }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.black)
                .tint(Theme.accent)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color(white: 0.898), lineWidth: 1)
                        )
                )
            }

            // Favorite toggle.
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.15))
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pin to Suggested")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Always one tap away on the Send tab.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.grayText)
                }

                Spacer()

                Toggle("", isOn: $isFavorite)
                    .labelsHidden()
                    .tint(Theme.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(white: 0.898), lineWidth: 1)
                    )
            )

            Button {
                guard hasChanges else { dismiss(); return }
                var updated = beneficiary
                let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.nickname = trimmed.isEmpty ? nil : trimmed
                updated.isFavorite = isFavorite
                onSave(updated)
                dismiss()
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        hasChanges ? Theme.accent : Theme.accent.opacity(0.45),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!hasChanges)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { nicknameFocused = true }
        }
    }
}
