import SwiftUI

struct HomeView: View {
    @Environment(WalletStore.self) private var wallet
    @Environment(VirtualCardStore.self) private var cards

    @State private var query: String = ""
    @State private var showTopUp: Bool = false
    @State private var showCardTerms: Bool = false
    @State private var goToCreateCard: Bool = false
    @State private var goToCardsList: Bool = false
    @State private var pushedCardId: UUID? = nil
    @State private var showVerifyEmail: Bool = false

    var body: some View {
        NavigationStack {
            content
                .sheet(isPresented: $showCardTerms) {
                    CardTermsSheet(onAccepted: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            goToCreateCard = true
                        }
                    })
                }
                .navigationDestination(isPresented: $goToCreateCard) {
                    CreateCardView()
                }
                .navigationDestination(isPresented: $goToCardsList) {
                    CardsListView()
                }
                .navigationDestination(item: $pushedCardId) { id in
                    CardDetailView(cardId: id)
                }
        }
    }

    private var content: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Avatar + glass search bar.
                    HStack(spacing: 12) {
                        Image("settings_avatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.7))
                            TextField(
                                "",
                                text: $query,
                                prompt: Text("Search").foregroundStyle(.white.opacity(0.7))
                            )
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .tint(.white)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 17))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                    // Card hero with gradient fade + Get Virtual Card pill.
                    ZStack {
                        Image("cards")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 333)
                            .mask(
                                LinearGradient(
                                    colors: [.black, .black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        VStack(spacing: 8) {
                            if wallet.isAccountVerified {
                                Button {
                                    showCardTerms = true
                                } label: {
                                    Text("Get Virtual Card")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .glassEffect(.regular.interactive(), in: .capsule)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    showVerifyEmail = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "envelope")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("Verify your email")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 12)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Account is under review")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(Color(red: 1, green: 0xCC/255, blue: 0))
                            }
                            Spacer()
                        }
                        .padding(.top, 78)
                    }
                    .frame(height: 333)
                    .padding(.horizontal, 22)

                    // Wallet balance + Top Up + Recent activities.
                    VStack(spacing: 20) {
                        // Wallet balance + Top Up.
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Wallet Balance")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                                Spacer(minLength: 0)
                                HStack(spacing: 6) {
                                    CurrencyIcon(size: 16)
                                    Text(WalletStore.formatMoney(wallet.balance))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .frame(width: 176, height: 65, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))

                            Spacer()

                            VStack(spacing: 8) {
                                Button {
                                    showTopUp = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(12)
                                        .glassEffect(.regular.interactive(), in: .circle)
                                }
                                .buttonStyle(.plain)

                                Text("Top Up")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }

                        // Recent activities.
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Activities")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("View All")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                            }

                            VStack(spacing: 16) {
                                ActivityRow(icon: "arrow.left.arrow.right", title: "Transfer",   date: "07/12/2023, 02:30 PM", amount: "12,900")
                                ActivityRow(icon: "arrow.right",             title: "Cash-out",  date: "YESTERDAY, 10:03 AM",  amount: "12,900")
                                ActivityRow(icon: "arrow.right",             title: "Cash-out",  date: "YESTERDAY, 10:03 AM",  amount: "12,900")
                                ActivityRow(icon: "arrow.left.arrow.right", title: "Transfer",   date: "YESTERDAY, 10:03 AM",  amount: "12,900")
                                ActivityRow(icon: "arrow.left.arrow.right", title: "Transfer",   date: "YESTERDAY, 10:03 AM",  amount: "12,900")
                                ActivityRow(icon: "arrow.left.arrow.right", title: "Transfer",   date: "YESTERDAY, 4:20 PM",   amount: "900")
                            }
                            .padding(12)
                            .background(Theme.card, in: .rect(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, -52)
                    .padding(.bottom, 60)
                }
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showTopUp) {
            TopUpView()
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showVerifyEmail) {
            VerifyEmailSheet(onVerify: {
                wallet.isAccountVerified = true
            })
        }
    }
}

private struct ActivityRow: View {
    var icon: String
    var title: String
    var date: String
    var amount: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0x03/255, green: 0x01/255, blue: 0x26/255))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(date)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                }
            }

            Spacer()

            HStack(spacing: 4) {
                CurrencyIcon(size: 14)
                Text(amount)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct CurrencyIcon: View {
    var size: CGFloat = 16
    var color: Color = .white

    var body: some View {
        Image("currency_baht")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .foregroundStyle(color)
    }
}
