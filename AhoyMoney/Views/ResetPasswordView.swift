import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: () -> Void = {}

    enum Field: Hashable { case password, confirm }

    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirm: Bool = false
    @State private var showToast: Bool = false
    @FocusState private var focused: Field?

    private var canSave: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Forget Password")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(.white)

                        Spacer()
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 24) {
                    Text("Enter your new password below")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 28)

                    VStack(spacing: 16) {
                        AppPasswordField(placeholder: "Password", text: $password, isVisible: $showPassword, submitLabel: .next, onSubmit: { focused = .confirm })
                            .focused($focused, equals: .password)
                        AppPasswordField(placeholder: "Re-type new password", text: $confirmPassword, isVisible: $showConfirm, submitLabel: .done, onSubmit: { focused = nil })
                            .focused($focused, equals: .confirm)

                        Button {
                            if canSave {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    showToast = true
                                }
                                Task {
                                    try? await Task.sleep(for: .seconds(1.6))
                                    onSave()
                                }
                            }
                        } label: {
                            Text("Save")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(
                                    canSave ? Color.white : Color.white.opacity(0.45),
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 22)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .liquidGlassToast(
            isPresented: $showToast,
            message: "Password changed successfully",
            duration: 1.5
        )
    }

}
