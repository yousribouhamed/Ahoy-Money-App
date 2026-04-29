import SwiftUI
import UniformTypeIdentifiers

struct FillDetailsView: View {
    enum UploadSlot: Identifiable {
        case income, address
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss

    var onContinue: () -> Void = {}

    @State private var residency: String = ""
    @State private var income: String = ""
    @State private var occupation: String = ""
    @State private var international: String = ""
    @State private var avgTxn: String = ""
    @State private var expectedBalance: String = ""
    @State private var pep: String = ""
    @State private var proofIncomeName: String? = nil
    @State private var proofAddressName: String? = nil
    @State private var importingSlot: UploadSlot? = nil

    private var proofIncomeUploaded: Bool { proofIncomeName != nil }
    private var proofAddressUploaded: Bool { proofAddressName != nil }

    private let residencyOptions = ["UAE Resident", "Non-Resident", "Visitor"]
    private let incomeOptions = ["Salary", "Business", "Investments", "Other"]
    private let occupationOptions = ["Employed", "Self-Employed", "Student", "Retired", "Other"]
    private let yesNoOptions = ["Yes", "No"]
    private let txnSizeOptions = ["< AED 1,000", "AED 1,000 – 5,000", "AED 5,000 – 20,000", "> AED 20,000"]
    private let balanceOptions = ["< AED 5,000", "AED 5,000 – 25,000", "AED 25,000 – 100,000", "> AED 100,000"]

    private var allFilled: Bool {
        ![residency, income, occupation, international, avgTxn, expectedBalance, pep].contains(where: \.isEmpty)
            && proofIncomeUploaded && proofAddressUploaded
    }

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Progress: first 4 white, last cyan.
                    HStack(spacing: 8) {
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Color.white).frame(height: 6)
                        Capsule().fill(Theme.accent).frame(height: 6)
                    }
                    .padding(.top, 8)
                    .scrollEdgeBlur()

                    // Header.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text("4")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent, in: .circle)

                            Text("Fill Details")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("Please complete following details")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.top, 8)
                    .scrollEdgeBlur()

                    // Dropdown fields.
                    VStack(spacing: 16) {
                        dropdown("Residency Status", selection: $residency, options: residencyOptions).scrollEdgeBlur()
                        dropdown("What's your primary source of income?", selection: $income, options: incomeOptions).scrollEdgeBlur()
                        dropdown("What's your Occupation", selection: $occupation, options: occupationOptions).scrollEdgeBlur()
                        dropdown("Do you expected to use your wallet for international money transfer ?", selection: $international, options: yesNoOptions).scrollEdgeBlur()
                        dropdown("What is your expected average transaction size?", selection: $avgTxn, options: txnSizeOptions).scrollEdgeBlur()
                        dropdown("What is your expected wallet balance?", selection: $expectedBalance, options: balanceOptions).scrollEdgeBlur()
                        dropdown("Are you a PEP (Politically Exposed Person) or close associate of PEP?", selection: $pep, options: yesNoOptions).scrollEdgeBlur()
                    }
                    .padding(.top, 8)

                    // Upload boxes.
                    VStack(spacing: 16) {
                        uploadBox(
                            slot: .income,
                            title: "Upload Proof of Income",
                            subtitle: "PDF/DOC",
                            fileName: proofIncomeName
                        ).scrollEdgeBlur()
                        uploadBox(
                            slot: .address,
                            title: "Upload Proof of Address",
                            subtitle: "PDF/DOC",
                            fileName: proofAddressName
                        ).scrollEdgeBlur()
                    }
                    .padding(.top, 4)

                    // Continue button.
                    Button {
                        if allFilled { onContinue() }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                allFilled ? Color.white : Color.white.opacity(0.35),
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!allFilled)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                    .scrollEdgeBlur()
                }
                .padding(.horizontal, 22)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .safeAreaInset(edge: .top, spacing: 0) {
                topBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
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

                Button {
                    if allFilled { onContinue() }
                } label: {
                    Text("Next")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 3/255, green: 1/255, blue: 38/255))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(allFilled ? Theme.accent : Color.white.opacity(0.25), in: .capsule)
                }
                .buttonStyle(.plain)
                .disabled(!allFilled)
            }
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 8)
    }

    private func dropdown(_ placeholder: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(opt) { selection.wrappedValue = opt }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(selection.wrappedValue.isEmpty ? placeholder : selection.wrappedValue)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(selection.wrappedValue.isEmpty ? Color.white.opacity(0.55) : .white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }

    private func uploadBox(slot: UploadSlot, title: String, subtitle: String, fileName: String?) -> some View {
        let uploaded = fileName != nil
        return Button {
            importingSlot = slot
        } label: {
            VStack(spacing: 8) {
                Image(systemName: uploaded ? "checkmark.circle.fill" : "arrow.up.doc.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(uploaded ? Theme.accent : Color.white.opacity(0.85))

                Text(uploaded ? (fileName ?? "") : title)
                    .font(.system(size: 16, weight: uploaded ? .semibold : .regular))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .truncationMode(.middle)

                Text(uploaded ? "Tap to replace" : subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    uploaded ? Theme.accent.opacity(0.7) : Color.white.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.2, dash: uploaded ? [] : [8, 6])
                )
        )
        .fileImporter(
            isPresented: Binding(
                get: { importingSlot == slot },
                set: { if !$0 { importingSlot = nil } }
            ),
            allowedContentTypes: [.pdf, UTType("com.microsoft.word.doc") ?? .data, UTType("org.openxmlformats.wordprocessingml.document") ?? .data, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let name = url.lastPathComponent
                switch slot {
                case .income: proofIncomeName = name
                case .address: proofAddressName = name
                }
            }
        }
    }
}

