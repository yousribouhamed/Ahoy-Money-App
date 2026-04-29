import SwiftUI

struct UpdatePhoneSheet: View {
    @Environment(\.dismiss) private var dismiss

    var initialCode: String = "+971"
    var initialPhone: String = ""
    var onSendCode: (_ code: String, _ phone: String) -> Void = { _, _ in }

    @State private var code: String
    @State private var phone: String
    @FocusState private var focused: Bool

    init(
        initialCode: String = "+971",
        initialPhone: String = "",
        onSendCode: @escaping (String, String) -> Void = { _, _ in }
    ) {
        self.initialCode = initialCode
        self.initialPhone = initialPhone
        self.onSendCode = onSendCode
        _code = State(initialValue: initialCode)
        _phone = State(initialValue: initialPhone)
    }

    private var canSend: Bool {
        let digits = phone.trimmingCharacters(in: .whitespaces)
        return digits.count >= 6 && !code.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter new phone number")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("A 6-digit verification code will be sent via SMS to confirm this is your number.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.grayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                // Country dialing-code Menu (iOS 26 liquid glass).
                Menu {
                    ForEach(Countries.all) { c in
                        Button {
                            code = "+" + dialingCode(for: c.code)
                        } label: {
                            Text("\(c.name)  +\(dialingCode(for: c.code))")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(code)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.grayText)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color(white: 0.898), lineWidth: 1)
                            )
                    )
                }

                TextField("", text: $phone, prompt: Text("Phone number").foregroundStyle(Theme.grayText))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { focused = false }
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

            Button {
                if canSend {
                    onSendCode(code, phone)
                    dismiss()
                }
            } label: {
                Text("Send OTP Code")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        canSend ? Theme.accent : Theme.accent.opacity(0.45),
                        in: .capsule
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .presentationBackground(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true }
        }
    }

    /// Best-effort ISO-region → dialing-code lookup.
    private func dialingCode(for region: String) -> String {
        // Simple lookup table for common cases — falls back to the region code.
        let table: [String: String] = [
            "US": "1", "CA": "1", "GB": "44", "FR": "33", "DE": "49",
            "IT": "39", "ES": "34", "AE": "971", "SA": "966", "EG": "20",
            "DZ": "213", "MA": "212", "TN": "216", "TR": "90", "IN": "91",
            "CN": "86", "JP": "81", "KR": "82", "BR": "55", "MX": "52",
            "AU": "61", "NZ": "64", "RU": "7", "ZA": "27", "NG": "234",
            "PK": "92", "BD": "880", "ID": "62", "TH": "66", "VN": "84",
            "PH": "63", "MY": "60", "SG": "65", "QA": "974", "KW": "965",
            "BH": "973", "OM": "968", "JO": "962", "LB": "961", "IQ": "964",
            "IR": "98", "IL": "972", "PT": "351", "NL": "31", "BE": "32",
            "CH": "41", "AT": "43", "SE": "46", "NO": "47", "DK": "45",
            "FI": "358", "PL": "48", "CZ": "420", "GR": "30", "IE": "353",
            "UA": "380", "RO": "40", "HU": "36"
        ]
        return table[region] ?? region
    }
}
