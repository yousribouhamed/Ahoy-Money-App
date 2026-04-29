import SwiftUI

struct CreatePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    var onContinue: () -> Void = {}

    enum Field: Hashable { case password, confirm }

    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirm: Bool = false
    @FocusState private var focused: Field?

    private var canContinue: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Setup Wallet")
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

                VStack(spacing: 16) {
                    AppPasswordField(placeholder: "Password", text: $password, isVisible: $showPassword, submitLabel: .next, onSubmit: { focused = .confirm })
                        .focused($focused, equals: .password)
                    AppPasswordField(placeholder: "Confirm Password", text: $confirmPassword, isVisible: $showConfirm, submitLabel: .done, onSubmit: { focused = nil })
                        .focused($focused, equals: .confirm)

                    Button {
                        if canContinue { onContinue() }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                canContinue ? Color.white : Color.white.opacity(0.5),
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 22)
                .padding(.top, 32)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

}
