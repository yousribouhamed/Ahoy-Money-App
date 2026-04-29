import SwiftUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    enum Field: Hashable { case name, phone }

    @State private var name: String = "Yousri Bouhamed"
    @State private var email: String = "yybouhamed@gmail.com"
    @State private var phoneCode: String = "+971"
    @State private var phone: String = "586272193"
    @State private var country: String = "Algeria"
    @State private var showUpdateEmail: Bool = false
    @State private var showVerifyNewEmail: Bool = false
    @State private var pendingEmail: String = ""

    @State private var showUpdatePassword: Bool = false
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    @State private var photoPickerSource: ImagePicker.Source? = nil
    @State private var profileImage: UIImage? = nil

    @State private var showUpdatePhone: Bool = false
    @State private var showVerifyNewPhone: Bool = false
    @State private var pendingPhoneCode: String = ""
    @State private var pendingPhone: String = ""
    @FocusState private var focused: Field?

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Edit Profile")
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

                        Button {
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0, green: 0.478, blue: 1), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 28) {
                        // Profile pill.
                        HStack(spacing: 10) {
                            Group {
                                if let img = profileImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image("settings_avatar")
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                            .frame(width: 48, height: 48)
                            .background(Color(red: 1, green: 0.86, blue: 0.87))
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 0) {
                                Text(name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(email)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                            }

                            Spacer()

                            Menu {
                                Button {
                                    photoPickerSource = .camera
                                } label: {
                                    Label("Take Photo", systemImage: "camera")
                                }
                                Button {
                                    photoPickerSource = .library
                                } label: {
                                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                                }
                            } label: {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .menuStyle(.button)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .controlSize(.regular)
                            .tint(.white)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 65.5)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1), in: .rect(cornerRadius: 16))
                        .scrollEdgeBlur()

                        // Profile Settings.
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Profile Settings")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)

                            VStack(spacing: 10) {
                                // Name field.
                                TextField("", text: $name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .tint(.white)
                                    .focused($focused, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit { focused = .phone }
                                    .padding(.horizontal, 16)
                                    .frame(height: 52)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.card, in: .rect(cornerRadius: 16))

                                // Email + Update.
                                HStack {
                                    Text(email)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button {
                                        showUpdateEmail = true
                                    } label: {
                                        Text("Update")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Theme.accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .frame(maxWidth: .infinity)
                                .background(Theme.card, in: .rect(cornerRadius: 16))

                                // Password + Update.
                                HStack {
                                    Text("Password")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                    Spacer()
                                    Button {
                                        showUpdatePassword = true
                                    } label: {
                                        Text("Update")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(Theme.accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .frame(maxWidth: .infinity)
                                .background(Theme.card, in: .rect(cornerRadius: 16))

                                // Phone row — tap to update (verification required).
                                Button {
                                    showUpdatePhone = true
                                } label: {
                                    HStack(spacing: 12) {
                                        HStack(spacing: 10) {
                                            Text(phoneCode)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.white)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        .padding(16)
                                        .background(Theme.card, in: .rect(cornerRadius: 16))

                                        HStack {
                                            Text(phone)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text("Update")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(Theme.accent)
                                        }
                                        .padding(.horizontal, 16)
                                        .frame(height: 52)
                                        .frame(maxWidth: .infinity)
                                        .background(Theme.card, in: .rect(cornerRadius: 16))
                                    }
                                }
                                .buttonStyle(.plain)

                                // Country — iOS 26 native Menu (liquid glass dropdown).
                                Menu {
                                    ForEach(Countries.all) { c in
                                        Button {
                                            country = c.name
                                        } label: {
                                            Text(c.name)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Country")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.accent)
                                        Spacer()
                                        HStack(spacing: 8) {
                                            Text(country)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Theme.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(height: 45)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.card, in: .rect(cornerRadius: 16))
                                }
                                .menuStyle(.button)
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollEdgeBlur()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showUpdateEmail) {
            UpdateEmailSheet(onSendCode: { newEmail in
                pendingEmail = newEmail
                // Defer presentation until after the first sheet finishes dismissing.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showVerifyNewEmail = true
                }
            })
        }
        .sheet(isPresented: $showVerifyNewEmail) {
            VerifyNewEmailSheet(onVerify: {
                email = pendingEmail
                toastMessage = "Email updated successfully"
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showToast = true
                }
            })
        }
        .sheet(isPresented: $showUpdatePassword) {
            UpdatePasswordSheet(onConfirmed: {
                toastMessage = "Password changed — please log in again"
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showToast = true
                }
                // Brief pause so the user can read the toast, then sign out.
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    router.isAuthenticated = false
                }
            })
        }
        .liquidGlassToast(
            isPresented: $showToast,
            message: toastMessage,
            duration: 2.0
        )
        .sheet(item: $photoPickerSource) { source in
            ImagePicker(source: source) { image in
                profileImage = image
                toastMessage = "Profile photo updated"
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showToast = true
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showUpdatePhone) {
            UpdatePhoneSheet(
                initialCode: phoneCode,
                initialPhone: phone,
                onSendCode: { code, number in
                    pendingPhoneCode = code
                    pendingPhone = number
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        showVerifyNewPhone = true
                    }
                }
            )
        }
        .sheet(isPresented: $showVerifyNewPhone) {
            VerifyNewPhoneSheet(
                maskedNumber: maskNumber(code: pendingPhoneCode, phone: pendingPhone),
                onVerify: {
                    phoneCode = pendingPhoneCode
                    phone = pendingPhone
                    toastMessage = "Phone number updated successfully"
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        showToast = true
                    }
                }
            )
        }
    }

    /// "+971 5•••••193" — keeps prefix and last 3 digits visible.
    private func maskNumber(code: String, phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        guard digits.count > 4 else { return "\(code) \(digits)" }
        let head = String(digits.prefix(1))
        let tail = String(digits.suffix(3))
        let dotCount = max(digits.count - 4, 1)
        return "\(code) \(head)\(String(repeating: "•", count: dotCount))\(tail)"
    }
}
