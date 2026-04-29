import SwiftUI

/// Full-screen, multi-step "Add New Beneficiary" flow.
///
/// One container view, three branches keyed off `kind`. The chrome (top bar,
/// progress segments, step counter, primary CTA) is shared across every step
/// and every branch so the user always knows where they are and what to do
/// next. Steps are revealed progressively — never more than 3-4 fields per
/// screen — with smart defaults, inline validation, and a "verify" pattern
/// that turns trust signals (resolved name on IBAN, found wallet user) into
/// the moment that earns the user's confidence before they hit Confirm.
struct AddBeneficiaryView: View {
    let kind: BeneficiaryKind

    @Environment(\.dismiss) private var dismiss
    @Environment(BeneficiaryStore.self) private var store

    // MARK: - Step state

    @State private var step: Int = 0

    // MARK: - Wallet flow
    @State private var walletPhone: String = ""
    @State private var walletPhoneCode: String = "+971"
    @State private var walletLookup: LookupState = .idle
    @State private var walletResolvedName: String = ""

    // MARK: - UAE flow
    @State private var uaeBank: UAEBank = .enbd
    @State private var uaeAccountHolder: String = ""
    @State private var uaeIBAN: String = ""
    @State private var uaeIBANState: LookupState = .idle
    @State private var uaeMobile: String = ""
    @State private var uaeMobileCode: String = "+971"
    @State private var uaeEmail: String = ""

    // MARK: - International flow
    @State private var intlCountry: WorldCountry = Countries.all.first ?? .placeholder
    @State private var intlCurrency: String = "USD"
    @State private var intlBankName: String = ""
    @State private var intlSwift: String = ""
    @State private var intlBankAddress: String = ""
    @State private var intlFullName: String = ""
    @State private var intlAccount: String = ""
    @State private var intlAddress1: String = ""
    @State private var intlAddress2: String = ""
    @State private var intlMobile: String = ""
    @State private var intlMobileCode: String = "+971"
    @State private var intlEmail: String = ""
    @State private var intlPurpose: TransferPurpose = .familySupport

    // MARK: - Shared
    @State private var nickname: String = ""
    @State private var saveAsFavorite: Bool = true

    // MARK: - Sheets
    @State private var showOtp: Bool = false
    @State private var showSuccess: Bool = false

    @FocusState private var focused: FocusedField?

    enum FocusedField: Hashable { case phone, iban, accountHolder, mobile, email, fullName, account, addr1, addr2, bankName, swift, bankAddr, nickname }
    enum LookupState { case idle, searching, found, notFound }

    // MARK: - Derived

    private var totalSteps: Int {
        switch kind {
        case .wallet:        return 1
        case .uae:           return 3
        case .international: return 4
        }
    }

    private var screenTitle: String {
        switch kind {
        case .wallet:        return "Ahoy Wallet"
        case .uae:           return "UAE Bank"
        case .international: return "International"
        }
    }

    private var primaryCTA: String {
        // Last step on every flow asks the user to "Confirm" — earlier steps say "Continue".
        step == totalSteps - 1 ? "Confirm with Face ID" : "Continue"
    }

    /// Drives the disabled state of the bottom button.
    private var canAdvance: Bool {
        switch kind {
        case .wallet:
            return walletLookup == .found
        case .uae:
            switch step {
            case 0: return uaeIBANState == .found && !uaeAccountHolder.isEmpty
            case 1: return uaeMobile.filter(\.isNumber).count >= 6
            case 2: return true
            default: return false
            }
        case .international:
            switch step {
            case 0: return !intlCurrency.isEmpty
            case 1: return !intlBankName.isEmpty && intlSwift.count >= 8
            case 2: return !intlFullName.isEmpty
                 && intlAccount.count >= 6
                 && !intlAddress1.isEmpty
                 && intlMobile.filter(\.isNumber).count >= 6
            case 3: return true
            default: return false
            }
        }
    }

    // MARK: - View

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                topBar

                progressHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        stepBody
                            .scrollEdgeBlur()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)

                bottomBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showOtp) {
            BeneficiaryOtpSheet(
                kindLabel: screenTitle,
                onVerify: completeAndPushSuccess
            )
        }
        .navigationDestination(isPresented: $showSuccess) {
            BeneficiarySuccessView(beneficiary: makeBeneficiary())
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        ZStack {
            Text(screenTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Button {
                    if step == 0 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            step -= 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)

                Spacer()

                // Visual balance — keeps the title centered.
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 8)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressSegments(total: totalSteps, active: step + 1)
                .frame(height: 6)

            HStack {
                Text("Step \(step + 1) of \(totalSteps)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                Spacer()

                if let label = stepLabel {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    /// Short caption next to the step counter — orients the user.
    private var stepLabel: String? {
        switch (kind, step) {
        case (.wallet, 0):        return "Find your friend"
        case (.uae, 0):           return "Bank details"
        case (.uae, 1):           return "Contact"
        case (.uae, 2):           return "Review"
        case (.international, 0): return "Destination"
        case (.international, 1): return "Bank"
        case (.international, 2): return "Beneficiary"
        case (.international, 3): return "Review"
        default:                  return nil
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryWhiteButton(title: primaryCTA, enabled: canAdvance) {
                advance()
            }

            if step == totalSteps - 1 {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Secured by Face ID + 6-digit OTP")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Theme.accent.opacity(0.8))
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    // MARK: - Step body

    @ViewBuilder
    private var stepBody: some View {
        switch kind {
        case .wallet:        walletStep
        case .uae:           uaeStep
        case .international: intlStep
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Wallet flow
    // ─────────────────────────────────────────────────────────────────────

    @ViewBuilder
    private var walletStep: some View {
        StepHeader(
            title: "Find your friend",
            subtitle: "Enter their phone number — if they're on Ahoy, we'll find them instantly."
        )

        // Phone with country dial-code menu.
        HStack(spacing: 10) {
            DialCodeMenu(code: $walletPhoneCode)

            TextField(
                "",
                text: $walletPhone,
                prompt: Text("Phone number").foregroundStyle(.white.opacity(0.45))
            )
            .keyboardType(.phonePad)
            .focused($focused, equals: .phone)
            .submitLabel(.next)
            .onSubmit { focused = .nickname }
            .onChange(of: walletPhone) { _, newValue in
                walletPhone = newValue.filter(\.isNumber)
                triggerWalletLookup()
            }
            .darkFieldStyle()
        }

        // Live lookup state — the trust moment.
        Group {
            switch walletLookup {
            case .idle:
                EmptyView()
            case .searching:
                LookupStatusView(state: .searching, text: "Searching Ahoy directory…")
            case .found:
                ResolvedUserCard(name: walletResolvedName, phone: "\(walletPhoneCode) \(maskPhone(walletPhone))")
            case .notFound:
                LookupStatusView(state: .notFound, text: "No Ahoy user found with this number.")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: walletLookup)

        if walletLookup == .found {
            nicknameAndFavorite
        }
    }

    private func triggerWalletLookup() {
        let digits = walletPhone.filter(\.isNumber)
        guard digits.count >= 6 else {
            walletLookup = .idle
            return
        }
        walletLookup = .searching
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            // Demo: resolve any 9+ digit number to a fake friend.
            await MainActor.run {
                if digits.count >= 9 {
                    walletResolvedName = "Yousri B."
                    walletLookup = .found
                } else {
                    walletLookup = .notFound
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: UAE flow
    // ─────────────────────────────────────────────────────────────────────

    @ViewBuilder
    private var uaeStep: some View {
        switch step {
        case 0: uaeBankStep
        case 1: uaeContactStep
        case 2: uaeReviewStep
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var uaeBankStep: some View {
        StepHeader(
            title: "Send to a UAE bank",
            subtitle: "We'll resolve the account name from the IBAN — make sure it matches before you confirm."
        )

        FieldLabel("Bank")
        Menu {
            ForEach(UAEBank.allCases) { bank in
                Button {
                    uaeBank = bank
                    revalidateIBAN()
                } label: {
                    Text(bank.displayName)
                }
            }
        } label: {
            HStack {
                Text(uaeBank.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .darkFieldStyle()
        }

        FieldLabel("Account holder name")
        TextField(
            "",
            text: $uaeAccountHolder,
            prompt: Text("Full legal name").foregroundStyle(.white.opacity(0.45))
        )
        .focused($focused, equals: .accountHolder)
        .submitLabel(.next)
        .onSubmit { focused = .iban }
        .darkFieldStyle()

        FieldLabel("IBAN")
        TextField(
            "",
            text: $uaeIBAN,
            prompt: Text("AE07 0331 2345 6789 0123 456").foregroundStyle(.white.opacity(0.45))
        )
        .keyboardType(.asciiCapable)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled(true)
        .focused($focused, equals: .iban)
        .submitLabel(.done)
        .onSubmit { focused = nil }
        .onChange(of: uaeIBAN) { _, _ in revalidateIBAN() }
        .darkFieldStyle()

        // IBAN resolve banner.
        switch uaeIBANState {
        case .idle:
            EmptyView()
        case .searching:
            LookupStatusView(state: .searching, text: "Verifying IBAN with \(uaeBank.displayName)…")
        case .found:
            ResolvedAccountCard(
                accountName: uaeAccountHolder.isEmpty ? "Yousri Bouhamed" : uaeAccountHolder,
                bank: uaeBank.displayName,
                masked: maskIBAN(uaeIBAN)
            )
        case .notFound:
            LookupStatusView(state: .notFound, text: "We couldn't verify this IBAN. Double-check the digits.")
        }
    }

    private func revalidateIBAN() {
        let cleaned = uaeIBAN.filter { $0.isNumber || $0.isLetter }.uppercased()
        guard cleaned.count >= 15 else {
            uaeIBANState = .idle
            return
        }
        uaeIBANState = .searching
        Task {
            try? await Task.sleep(for: .seconds(1.0))
            await MainActor.run {
                if cleaned.count >= 22 && cleaned.hasPrefix("AE") {
                    uaeIBANState = .found
                } else {
                    uaeIBANState = .notFound
                }
            }
        }
    }

    @ViewBuilder
    private var uaeContactStep: some View {
        StepHeader(
            title: "How can we reach them?",
            subtitle: "We'll let \(uaeAccountHolder.isEmpty ? "your beneficiary" : uaeAccountHolder.firstName) know when money arrives."
        )

        FieldLabel("Mobile number")
        HStack(spacing: 10) {
            DialCodeMenu(code: $uaeMobileCode)

            TextField(
                "",
                text: $uaeMobile,
                prompt: Text("50 123 4567").foregroundStyle(.white.opacity(0.45))
            )
            .keyboardType(.phonePad)
            .focused($focused, equals: .mobile)
            .submitLabel(.next)
            .onSubmit { focused = .email }
            .onChange(of: uaeMobile) { _, newValue in
                uaeMobile = newValue.filter(\.isNumber)
            }
            .darkFieldStyle()
        }

        FieldLabel("Email")
        TextField(
            "",
            text: $uaeEmail,
            prompt: Text("Optional").foregroundStyle(.white.opacity(0.45))
        )
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .focused($focused, equals: .email)
        .submitLabel(.next)
        .onSubmit { focused = .nickname }
        .darkFieldStyle()

        nicknameAndFavorite
    }

    @ViewBuilder
    private var uaeReviewStep: some View {
        StepHeader(
            title: "Confirm new beneficiary",
            subtitle: "Review the details below. You'll authorise with Face ID and a 6-digit code."
        )

        ReviewCard {
            ReviewRow(label: "Bank", value: uaeBank.displayName)
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "Account holder", value: uaeAccountHolder)
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "IBAN", value: maskIBAN(uaeIBAN))
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "Mobile", value: "\(uaeMobileCode) \(uaeMobile)")
            if !uaeEmail.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                ReviewRow(label: "Email", value: uaeEmail)
            }
            if !nickname.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                ReviewRow(label: "Saved as", value: nickname)
            }
        }

        FavoriteCard(saveAsFavorite: $saveAsFavorite)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: International flow
    // ─────────────────────────────────────────────────────────────────────

    @ViewBuilder
    private var intlStep: some View {
        switch step {
        case 0: intlDestinationStep
        case 1: intlBankStep
        case 2: intlBeneficiaryStep
        case 3: intlReviewStep
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var intlDestinationStep: some View {
        StepHeader(
            title: "Where are we sending money?",
            subtitle: "Pick the country and the currency we should send in."
        )

        FieldLabel("Country")
        Menu {
            ForEach(Countries.all) { c in
                Button {
                    intlCountry = c
                    intlCurrency = currencyFor(country: c.code)
                } label: {
                    Text(c.name)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(intlCountry.flag).font(.system(size: 22))
                Text(intlCountry.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .darkFieldStyle()
        }

        FieldLabel("Currency")
        Menu {
            ForEach(commonCurrencies, id: \.self) { c in
                Button(c) { intlCurrency = c }
            }
        } label: {
            HStack {
                Text(intlCurrency)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .darkFieldStyle()
        }
    }

    @ViewBuilder
    private var intlBankStep: some View {
        StepHeader(
            title: "Bank information",
            subtitle: "Find these on your beneficiary's bank statement or online banking."
        )

        FieldLabel("Bank name")
        TextField(
            "",
            text: $intlBankName,
            prompt: Text("e.g. Barclays UK").foregroundStyle(.white.opacity(0.45))
        )
        .focused($focused, equals: .bankName)
        .submitLabel(.next)
        .onSubmit { focused = .swift }
        .darkFieldStyle()

        FieldLabel("SWIFT / BIC code")
        TextField(
            "",
            text: $intlSwift,
            prompt: Text("BARCGB22").foregroundStyle(.white.opacity(0.45))
        )
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled(true)
        .focused($focused, equals: .swift)
        .submitLabel(.next)
        .onSubmit { focused = .bankAddr }
        .onChange(of: intlSwift) { _, newValue in
            intlSwift = String(newValue.uppercased().prefix(11))
        }
        .darkFieldStyle()

        FieldLabel("Bank address")
        TextField(
            "",
            text: $intlBankAddress,
            prompt: Text("Optional").foregroundStyle(.white.opacity(0.45))
        )
        .focused($focused, equals: .bankAddr)
        .submitLabel(.done)
        .onSubmit { focused = nil }
        .darkFieldStyle()
    }

    @ViewBuilder
    private var intlBeneficiaryStep: some View {
        StepHeader(
            title: "Beneficiary info",
            subtitle: "Use the legal name exactly as it appears on the bank account."
        )

        FieldLabel("Full name")
        TextField(
            "",
            text: $intlFullName,
            prompt: Text("First and last name").foregroundStyle(.white.opacity(0.45))
        )
        .focused($focused, equals: .fullName)
        .submitLabel(.next)
        .onSubmit { focused = .account }
        .darkFieldStyle()

        FieldLabel("Account number / IBAN")
        TextField(
            "",
            text: $intlAccount,
            prompt: Text("GB29 NWBK 6016 1331 9268 19").foregroundStyle(.white.opacity(0.45))
        )
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled(true)
        .focused($focused, equals: .account)
        .submitLabel(.next)
        .onSubmit { focused = .addr1 }
        .darkFieldStyle()

        FieldLabel("Address")
        VStack(spacing: 10) {
            TextField(
                "",
                text: $intlAddress1,
                prompt: Text("Street address").foregroundStyle(.white.opacity(0.45))
            )
            .focused($focused, equals: .addr1)
            .submitLabel(.next)
            .onSubmit { focused = .addr2 }
            .darkFieldStyle()

            TextField(
                "",
                text: $intlAddress2,
                prompt: Text("City, postal code (optional)").foregroundStyle(.white.opacity(0.45))
            )
            .focused($focused, equals: .addr2)
            .submitLabel(.next)
            .onSubmit { focused = .mobile }
            .darkFieldStyle()
        }

        FieldLabel("Mobile number")
        HStack(spacing: 10) {
            DialCodeMenu(code: $intlMobileCode)

            TextField(
                "",
                text: $intlMobile,
                prompt: Text("Phone number").foregroundStyle(.white.opacity(0.45))
            )
            .keyboardType(.phonePad)
            .focused($focused, equals: .mobile)
            .submitLabel(.next)
            .onSubmit { focused = .email }
            .onChange(of: intlMobile) { _, newValue in
                intlMobile = newValue.filter(\.isNumber)
            }
            .darkFieldStyle()
        }

        FieldLabel("Email")
        TextField(
            "",
            text: $intlEmail,
            prompt: Text("Optional").foregroundStyle(.white.opacity(0.45))
        )
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .focused($focused, equals: .email)
        .submitLabel(.done)
        .onSubmit { focused = nil }
        .darkFieldStyle()
    }

    @ViewBuilder
    private var intlReviewStep: some View {
        StepHeader(
            title: "Almost done — confirm details",
            subtitle: "International transfers may need extra verification by our compliance team. SWIFT routing fees may apply."
        )

        ReviewCard {
            ReviewRow(label: "Country", value: "\(intlCountry.flag)  \(intlCountry.name)")
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "Currency", value: intlCurrency)
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "Bank", value: intlBankName)
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "SWIFT / BIC", value: intlSwift)
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "Beneficiary", value: intlFullName)
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "Account", value: intlAccount)
            Divider().background(Color.white.opacity(0.08))
            ReviewRow(label: "Mobile", value: "\(intlMobileCode) \(intlMobile)")
        }

        FieldLabel("Purpose of transfer")
        Menu {
            ForEach(TransferPurpose.allCases) { p in
                Button(p.label) { intlPurpose = p }
            }
        } label: {
            HStack {
                Text(intlPurpose.label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .darkFieldStyle()
        }

        if !nickname.isEmpty == false {
            // (Always show nickname/favorite block here so the user can edit before confirming.)
        }
        nicknameAndFavorite
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Shared blocks
    // ─────────────────────────────────────────────────────────────────────

    /// Shown on the last step of every flow — gives the user a single place
    /// to label and pin the contact before they confirm.
    @ViewBuilder
    private var nicknameAndFavorite: some View {
        FieldLabel("Save as (nickname)")
        TextField(
            "",
            text: $nickname,
            prompt: Text("e.g. Mum, Office, Sarah").foregroundStyle(.white.opacity(0.45))
        )
        .focused($focused, equals: .nickname)
        .submitLabel(.done)
        .onSubmit { focused = nil }
        .darkFieldStyle()

        FavoriteCard(saveAsFavorite: $saveAsFavorite)
    }

    // MARK: - Actions

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                step += 1
            }
            focused = nil
            return
        }

        // Last step — gate with biometrics, then OTP.
        BiometricAuth.authenticate(reason: "Authenticate to add this beneficiary") { success in
            if success {
                // Defer the sheet so the auth alert finishes dismissing cleanly.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showOtp = true
                }
            }
        }
    }

    private func completeAndPushSuccess() {
        store.add(makeBeneficiary())
        // Slight delay so the OTP sheet finishes dismissing before we push.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showSuccess = true
        }
    }

    private func makeBeneficiary() -> Beneficiary {
        switch kind {
        case .wallet:
            return Beneficiary(
                kind: .wallet,
                name: walletResolvedName,
                nickname: nickname.isEmpty ? nil : nickname,
                subtitle: "\(walletPhoneCode) \(maskPhone(walletPhone))",
                avatarBg: Color(red: 0.66, green: 0.93, blue: 1.00),
                isFavorite: saveAsFavorite,
                phone: walletPhone,
                phoneCode: walletPhoneCode
            )
        case .uae:
            return Beneficiary(
                kind: .uae,
                name: uaeAccountHolder,
                nickname: nickname.isEmpty ? nil : nickname,
                subtitle: "\(uaeBank.displayName) ••• \(String(uaeIBAN.suffix(4)))",
                avatarBg: Color(red: 1.00, green: 0.85, blue: 0.55),
                isFavorite: saveAsFavorite,
                phone: uaeMobile,
                phoneCode: uaeMobileCode,
                email: uaeEmail.isEmpty ? nil : uaeEmail,
                bankName: uaeBank.displayName,
                iban: uaeIBAN
            )
        case .international:
            let fullAddress = [intlAddress1, intlAddress2]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            return Beneficiary(
                kind: .international,
                name: intlFullName,
                nickname: nickname.isEmpty ? nil : nickname,
                subtitle: "\(intlBankName) • \(intlCurrency)",
                avatarBg: Color(red: 0.62, green: 0.86, blue: 0.70),
                isFavorite: saveAsFavorite,
                phone: intlMobile,
                phoneCode: intlMobileCode,
                email: intlEmail.isEmpty ? nil : intlEmail,
                bankName: intlBankName,
                swift: intlSwift,
                accountNumber: intlAccount,
                country: "\(intlCountry.flag) \(intlCountry.name)",
                currency: intlCurrency,
                address: fullAddress.isEmpty ? nil : fullAddress
            )
        }
    }

    // MARK: - Helpers

    private func maskPhone(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        guard digits.count > 4 else { return digits }
        let head = String(digits.prefix(1))
        let tail = String(digits.suffix(3))
        let dots = String(repeating: "•", count: max(digits.count - 4, 1))
        return head + dots + tail
    }

    private func maskIBAN(_ iban: String) -> String {
        let cleaned = iban.filter { $0.isLetter || $0.isNumber }.uppercased()
        guard cleaned.count > 8 else { return cleaned }
        let head = String(cleaned.prefix(4))
        let tail = String(cleaned.suffix(4))
        return "\(head) •••• •••• \(tail)"
    }

    private func currencyFor(country code: String) -> String {
        let map: [String: String] = [
            "US": "USD", "GB": "GBP", "FR": "EUR", "DE": "EUR", "IT": "EUR",
            "ES": "EUR", "AE": "AED", "SA": "SAR", "EG": "EGP", "DZ": "DZD",
            "MA": "MAD", "TN": "TND", "TR": "TRY", "IN": "INR", "CN": "CNY",
            "JP": "JPY", "KR": "KRW", "BR": "BRL", "MX": "MXN", "AU": "AUD",
            "NZ": "NZD", "RU": "RUB", "ZA": "ZAR", "NG": "NGN", "PK": "PKR",
            "BD": "BDT", "ID": "IDR", "TH": "THB", "VN": "VND", "PH": "PHP",
            "MY": "MYR", "SG": "SGD", "QA": "QAR", "KW": "KWD", "BH": "BHD",
            "OM": "OMR", "JO": "JOD", "LB": "LBP", "CA": "CAD", "CH": "CHF"
        ]
        return map[code] ?? "USD"
    }

    private let commonCurrencies: [String] = [
        "USD", "EUR", "GBP", "AED", "SAR", "INR", "PKR", "EGP",
        "TRY", "CAD", "AUD", "JPY", "CHF", "CNY", "SGD", "PHP"
    ]
}

// MARK: - Reusable building blocks (file-private)

private struct StepHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.bottom, -8)
            .padding(.top, 4)
    }
}

private struct DialCodeMenu: View {
    @Binding var code: String

    var body: some View {
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
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
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

    private func dialingCode(for region: String) -> String {
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

private struct LookupStatusView: View {
    let state: AddBeneficiaryView.LookupState
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Group {
                switch state {
                case .searching:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.accent)
                case .notFound:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Theme.warning)
                default:
                    EmptyView()
                }
            }
            .frame(width: 22, height: 22)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

/// The "trust moment" for the wallet flow — confirms the recipient is a real Ahoy user.
private struct ResolvedUserCard: View {
    let name: String
    let phone: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(red: 0.66, green: 0.93, blue: 1.00))
                Text(String(name.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text(phone)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            Text("Ahoy User")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.accent, in: .capsule)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Trust moment for UAE flow — shows the resolved account name from IBAN.
private struct ResolvedAccountCard: View {
    let accountName: String
    let bank: String
    let masked: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Verified — \(accountName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(bank)  •  \(masked)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct ReviewCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }
}

private struct ReviewRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private struct FavoriteCard: View {
    @Binding var saveAsFavorite: Bool
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.15))
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pin to Suggested")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Always keep this contact one tap away.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            Toggle("", isOn: $saveAsFavorite)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Domain types

enum UAEBank: String, CaseIterable, Identifiable {
    case enbd, mashreq, adcb, fab, dib, hsbc, rakbank
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .enbd:    return "Emirates NBD"
        case .mashreq: return "Mashreq Bank"
        case .adcb:    return "Abu Dhabi Commercial Bank"
        case .fab:     return "First Abu Dhabi Bank"
        case .dib:     return "Dubai Islamic Bank"
        case .hsbc:    return "HSBC UAE"
        case .rakbank: return "RAKBANK"
        }
    }
}

enum TransferPurpose: String, CaseIterable, Identifiable {
    case familySupport, business, education, medical, savings, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .familySupport: return "Family support"
        case .business:      return "Business"
        case .education:     return "Education"
        case .medical:       return "Medical"
        case .savings:       return "Savings"
        case .other:         return "Other"
        }
    }
}

// MARK: - Tiny extensions

private extension String {
    var firstName: String {
        split(separator: " ").first.map(String.init) ?? self
    }
}

private extension WorldCountry {
    /// Safe fallback if `Countries.all` is somehow empty.
    static let placeholder = WorldCountry(code: "US", name: "United States", flag: "🇺🇸")
}
