import SwiftUI

@main
struct AhoyMoneyApp: App {
    @State private var wallet = WalletStore()
    @State private var router = AppRouter()
    @State private var beneficiaries = BeneficiaryStore()
    @State private var cards = VirtualCardStore()
    @State private var help = HelpStore()
    @State private var upcomingTransfers = UpcomingTransferStore()
    @State private var searchStore = GlobalSearchStore()
    @State private var transactionStore = TransactionStore()
    @State private var chatStore = ChatStore()
    @State private var appearance = AppearanceStore()
    @State private var cardTransactions = CardTransactionStore()
    @State private var onboarding = OnboardingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(wallet)
                .environment(router)
                .environment(beneficiaries)
                .environment(cards)
                .environment(help)
                .environment(upcomingTransfers)
                .environment(searchStore)
                .environment(transactionStore)
                .environment(chatStore)
                .environment(appearance)
                .environment(cardTransactions)
                .environment(onboarding)
                .preferredColorScheme(appearance.mode.colorScheme)
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
    @Environment(OnboardingStore.self) private var onboarding

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
                    case .verifyingIdentity:
                        // The loader routes itself on whichever of the three
                        // outcomes the provider returns.
                        VerifyingIdentityView(
                            onComplete: { router.authPath.append(.fillDetails) },
                            onCaptureFailed: { router.authPath.append(.identityFailed) },
                            onRefused: { router.authPath.append(.systemRefused) }
                        )
                    case .identityFailed:
                        IdentityFailedDestination()
                    case .systemRefused:
                        SystemRefusedDestination()
                    case .fillDetails:
                        // The two exits. Confirm goes straight through; an edit
                        // sends them to review and nothing is issued yet.
                        // Fill Details records which exit was taken; the
                        // outcome isn't decided until the passcode is set,
                        // because the passcode is the last step of the journey.
                        FillDetailsView(onContinue: { needsReview in
                            if needsReview { onboarding.sendToReview(.editedDetails) }
                            router.authPath.append(.setPasscode)
                        })
                    case .setPasscode:
                        SetPasscodeView(onComplete: {
                            if onboarding.isHeldForReview {
                                // Nothing is issued until a person decides.
                                router.authPath.append(.heldForReview)
                            } else {
                                onboarding.approveInstantly()
                                // Straight into making the card, with the
                                // arrival screen left underneath so Back lands
                                // somewhere real rather than nowhere.
                                //
                                // The card is *not* issued automatically — that
                                // would mean choosing a name and a colour on the
                                // worker's behalf. Opening the flow gives them
                                // the card just as fast, and the choices stay
                                // theirs.
                                router.authPath.append(.walletCreated)
                                router.authPath.append(.createFirstCard)
                            }
                        })
                    case .createFirstCard:
                        CreateCardView(showsTermsFirst: true, onCancelled: {
                            // Backing out of the terms leaves them on the
                            // arrival screen, which still offers the card.
                            router.authPath.removeAll { $0 == .createFirstCard }
                        })
                    case .walletCreated:
                        WalletCreatedView(
                            onContinue: { router.isAuthenticated = true },
                            onCreateCard: {
                                router.pendingCardCreation = true
                                router.isAuthenticated = true
                            }
                        )
                    case .heldForReview: HeldForReviewDestination()
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

/// Pulled out of the route switch: pattern-matching the state inline made the
/// ViewBuilder too complex for the type checker.
struct HeldForReviewDestination: View {
    @Environment(OnboardingStore.self) private var onboarding
    @Environment(AppRouter.self) private var router

    var body: some View {
        if case let .underReview(since, reason, _) = onboarding.displayState {
            UnderReviewView(
                since: since,
                reason: reason,
                onExplore: { router.isAuthenticated = true }
            )
        } else {
            UnderReviewView(since: Date(), reason: .riskFactor)
        }
    }
}

/// Pulled out of the route switch to keep the ViewBuilder simple enough for
/// the type checker.
struct IdentityFailedDestination: View {
    @Environment(AppRouter.self) private var router
    @Environment(OnboardingStore.self) private var onboarding

    var body: some View {
        if case let .identityFailed(attemptsUsed, canRetry) = onboarding.displayState {
            IdentityFailedView(
                attemptsUsed: attemptsUsed,
                canRetry: canRetry,
                // Back to the start of capture.
                onRetry: {
                    router.authPath.removeAll {
                        $0 == .identityFailed || $0 == .verifyingIdentity
                    }
                }
            )
        }
    }
}

struct SystemRefusedDestination: View {
    @Environment(AppRouter.self) private var router
    @Environment(OnboardingStore.self) private var onboarding

    var body: some View {
        if case let .systemRefused(retryFrom) = onboarding.displayState {
            SystemRefusedView(
                retryFrom: retryFrom,
                onRetry: {
                    router.authPath.removeAll {
                        $0 == .systemRefused || $0 == .verifyingIdentity
                    }
                }
            )
        }
    }
}
