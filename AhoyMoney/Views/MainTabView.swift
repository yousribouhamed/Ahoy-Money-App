import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Wallet", systemImage: "wallet.pass.fill", value: AppRouter.Tab.wallet) {
                HomeView()
            }
            Tab("Send", systemImage: "arrow.left.arrow.right", value: AppRouter.Tab.send) {
                TransferView()
            }
            Tab("Transactions", systemImage: "rectangle.stack.fill", value: AppRouter.Tab.transactions) {
                TransactionsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppRouter.Tab.settings) {
                SettingsView()
            }
        }
        .tint(.white)
    }
}

private struct TabPlaceholder: View {
    let title: String
    var body: some View {
        ZStack {
            DarkGradientBackground()
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
