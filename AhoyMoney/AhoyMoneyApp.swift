import SwiftUI

@main
struct AhoyMoneyApp: App {
    @State private var wallet = WalletStore()
    @State private var router = AppRouter()
    @State private var beneficiaries = BeneficiaryStore()
    @State private var cards = VirtualCardStore()
    @State private var help = HelpStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(wallet)
                .environment(router)
                .environment(beneficiaries)
                .environment(cards)
                .environment(help)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        if router.isAuthenticated {
            MainTabView()
        } else {
            AuthNavigationView()
        }
    }
}

struct AuthNavigationView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var bindable = router
        NavigationStack(path: $bindable.authPath) {
            OnboardingView()
                .navigationDestination(for: AppRouter.Route.self) { route in
                    switch route {
                    case .login:       LoginView()
                    case .register:    RegisterView()
                    case .verifyOtp:   VerifyOtpView()
                    case .setupWallet: SetupWalletView(onContinue: { router.authPath.append(.scanID) })
                    case .scanID:      ScanIDView(onCapture: { router.authPath.append(.scanIDBack) })
                    case .scanIDBack:  ScanIDBackView(onComplete: { router.authPath.append(.selfieIntro) })
                    case .selfieIntro: SelfieIntroView(onContinue: { router.authPath.append(.selfieCapture) })
                    case .selfieCapture: SelfieCaptureView(onCapture: { router.authPath.append(.verifyingIdentity) })
                    case .verifyingIdentity: VerifyingIdentityView(onComplete: { router.authPath.append(.fillDetails) })
                    case .fillDetails: FillDetailsView(onContinue: { router.authPath.append(.createPassword) })
                    case .createPassword: CreatePasswordView(onContinue: { router.authPath.append(.walletCreated) })
                    case .walletCreated: WalletCreatedView(onContinue: { router.isAuthenticated = true })
                    case .forgetPassword: ForgetPasswordView(onContinue: { _ in router.authPath.append(.resetPassword) })
                    case .resetPassword: ResetPasswordView(onSave: {
                        router.authPath.removeAll { $0 == .forgetPassword || $0 == .resetPassword }
                    })
                    }
                }
        }
    }
}

struct PlaceholderView: View {
    let title: String
    var body: some View {
        ZStack {
            DarkGradientBackground()
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
