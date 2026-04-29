import SwiftUI

struct TermsConditionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var accepted: Bool = false
    var onAgree: () -> Void = {}
    var onDecline: () -> Void = {}

    private let bullets: [String] = [
        "By using this app, you agree to use it only for lawful purposes and in a way that does not harm, disrupt, or misuse the service.",
        "We may collect and process your information in accordance with our Privacy Policy.",
        "All content, features, and functionality in this app are owned by the company and may not be copied or reused without permission.",
        "We may update, suspend, or modify parts of the app at any time without prior notice.",
        "Your continued use of the app means you accept any updated terms."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title.
            Text("Terms and conditions")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)
                .padding(.top, 24)

            // Description.
            Text("Please read these Terms & Conditions carefully before using the app. By continuing, you agree to comply with and be bound by these terms.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(red: 0.45, green: 0.45, blue: 0.45))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            // Bullets card.
            VStack(alignment: .leading, spacing: 16) {
                ForEach(bullets, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                        Text(item)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.94, green: 0.94, blue: 0.94), in: .rect(cornerRadius: 12))
            .padding(.top, 20)

            // Checkbox row.
            Button {
                accepted.toggle()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                accepted ? Color(red: 0, green: 0.816, blue: 1) : Color(red: 0.78, green: 0.78, blue: 0.78),
                                lineWidth: 1.5
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(accepted ? Color(red: 0, green: 0.816, blue: 1) : Color.clear)
                            )
                            .frame(width: 22, height: 22)
                        if accepted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                        }
                    }

                    Text("I have read and agree to the Terms & Conditions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 20)

            // Action buttons.
            HStack(spacing: 16) {
                Button {
                    onDecline()
                    dismiss()
                } label: {
                    Text("Decline")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)

                Button {
                    if accepted {
                        onAgree()
                        dismiss()
                    }
                } label: {
                    Text("Agree & Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            accepted
                                ? Color(red: 0, green: 0.816, blue: 1)
                                : Color(red: 0, green: 0.816, blue: 1).opacity(0.5),
                            in: .capsule
                        )
                }
                .buttonStyle(.plain)
                .disabled(!accepted)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(.white)
        .interactiveDismissDisabled(true)
    }
}
