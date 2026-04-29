import SwiftUI

struct UpdatePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Called only after Face ID succeeds and the new password is confirmed.
    var onConfirmed: () -> Void = {}

    enum Field: Hashable { case password, confirm }

    @State private var password: String = ""
    @State private var confirm: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirm: Bool = false
    @FocusState private var focused: Field?

    private var canSave: Bool {
        password.count >= 6 && password == confirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Update password")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("Enter your new password. After updating, you'll be signed out and need to log in again with your new password.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                lightPasswordField(placeholder: "New password", text: $password, isVisible: $showPassword, field: .password, submit: .next, onSubmit: { focused = .confirm })
                lightPasswordField(placeholder: "Re-type password", text: $confirm, isVisible: $showConfirm, field: .confirm, submit: .done, onSubmit: { focused = nil })
            }

            Button {
                guard canSave else { return }
                BiometricAuth.authenticate(reason: "Authenticate to update your password") { success in
                    if success {
                        onConfirmed()
                        dismiss()
                    }
                }
            } label: {
                Text("Save")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        canSave ? Theme.accent : Theme.accent.opacity(0.45),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focused = .password
            }
        }
    }

    @ViewBuilder
    private func lightPasswordField(
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>,
        field: Field,
        submit: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Group {
                if isVisible.wrappedValue {
                    TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.grayText))
                } else {
                    SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.grayText))
                }
            }
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .focused($focused, equals: field)
            .submitLabel(submit)
            .onSubmit(onSubmit)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.black)
            .tint(Theme.accent)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye" : "eye.slash")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.grayText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.98)) // #FAFAFA
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(white: 0.898), lineWidth: 1) // #E5E5E5
                )
        )
    }
}
