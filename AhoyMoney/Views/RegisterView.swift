import SwiftUI

struct RegisterView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable { case username, email, phone }

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var code: String = "+971"
    @State private var phone: String = ""
    @State private var showingCountrySheet: Bool = false
    @FocusState private var focused: Field?

    private var isValid: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        email.contains("@") &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Register")
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
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                // Form block.
                VStack(spacing: 24) {
                    // Progress segments — step 1 of 2 complete, step 2 active.
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 8)
                        Capsule().fill(Theme.accent).frame(height: 8)
                    }

                    VStack(spacing: 20) {
                        darkField(placeholder: "Username", text: $username, secure: false)
                            .textContentType(.username)
                            .focused($focused, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focused = .email }

                        darkField(placeholder: "Email Address", text: $email, secure: false)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .focused($focused, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focused = .phone }

                        HStack(spacing: 12) {
                            Button {
                                showingCountrySheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text(code.isEmpty ? "+Code" : code)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(code.isEmpty ? Theme.subText : .white)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .frame(minWidth: 72)
                                .padding(.horizontal, 16)
                                .frame(height: 56)
                                .background(Theme.card, in: .rect(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)

                            darkField(placeholder: "Phone Number", text: $phone, secure: false)
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                                .focused($focused, equals: .phone)
                                .submitLabel(.done)
                                .onSubmit { focused = nil }
                        }
                    }

                    PrimaryWhiteButton(title: "Continue", enabled: isValid) {
                        router.authPath.append(.verifyOtp)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 40)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingCountrySheet) {
            CountryCodeSheet { country in
                code = country.code
            }
            .presentationDetents([.large])
            .presentationBackground(.clear)
        }
    }

    @ViewBuilder
    private func darkField(placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7)))
            } else {
                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Theme.accent.opacity(0.7)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
        }
        .darkFieldStyle()
    }
}
