import SwiftUI

struct TransactionsView: View {
    @Environment(WalletStore.self) private var wallet
    @Environment(AppRouter.self) private var router

    @State private var showTopUp: Bool = false

    var body: some View {
        NavigationStack {
            content
                .sheet(isPresented: $showTopUp) {
                    TopUpView()
                }
        }
    }

    private var content: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView {
                VStack(spacing: 0) {
                    // Top bar.
                    HStack(alignment: .center) {
                        // Wallet balance pill — same glass style as HomeView.
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Wallet Balance")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(red: 0, green: 0xAF/255, blue: 0xD6/255))
                            Spacer(minLength: 0)
                            HStack(spacing: 6) {
                                CurrencyIcon(size: 16)
                                Text(formattedBalance)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(12)
                        .frame(width: 176, height: 65, alignment: .leading)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                        Spacer()

                        // Send button.
                        VStack(spacing: 8) {
                            Button {
                                router.selectedTab = .send
                            } label: {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .controlSize(.large)
                            .tint(.white)

                            Text("Send")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                    // Stats row — stroke length encodes spend / limit.
                    HStack(spacing: 8) {
                        StatCard(title: "Monthly spending", amount: "400",  value: 400,  limit: 1500)
                        StatCard(title: "Monthly Top Up",   amount: "5300", value: 5300, limit: 10_000)
                        StatCard(title: "Monthly Transfer", amount: "7400", value: 7400, limit: 10_000)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                    // Months.
                    VStack(spacing: 24) {
                        MonthSection(title: "June 2025", items: june)
                        MonthSection(title: "May 2025",  items: may)
                        MonthSection(title: "April 2025", items: april)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Helpers.
    private var formattedBalance: String {
        let v = Int(wallet.balance.rounded())
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private var june: [TxnRowData] {
        [
            .init(kind: .transfer,  title: "Transfer",   timestamp: "07/12/2023, 02:30 PM", amount: "12,900"),
            .init(kind: .arrow,     title: "Cash-out",   timestamp: "YESTERDAY, 10:03 AM",  amount: "12,900"),
            .init(kind: .arrow,     title: "Withdrawal", timestamp: "YESTERDAY, 06:45 PM",  amount: "3,200"),
            .init(kind: .arrow,     title: "Deposit",    timestamp: "TODAY, 09:15 AM",      amount: "5,000")
        ]
    }

    private var may: [TxnRowData] {
        [
            .init(kind: .transfer, title: "Transfer", timestamp: "07/12/2023, 02:30 PM", amount: "12,900"),
            .init(kind: .arrow,    title: "Deposit",  timestamp: "TODAY, 09:15 AM",      amount: "5,000"),
            .init(kind: .transfer, title: "Transfer", timestamp: "YESTERDAY, 4:20 PM",   amount: "900 $", isDollar: true)
        ]
    }

    private var april: [TxnRowData] {
        [
            .init(kind: .arrow,    title: "Deposit",  timestamp: "TODAY, 09:15 AM",     amount: "5,000"),
            .init(kind: .transfer, title: "Transfer", timestamp: "YESTERDAY, 4:20 PM",  amount: "900 $", isDollar: true)
        ]
    }
}

// MARK: - Stat card.
/// The stroke around the card represents `value / limit` — a perimeter progress indicator.
private struct StatCard: View {
    let title: String
    let amount: String
    let value: Double
    let limit: Double

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(max(value / limit, 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                CurrencyIcon(size: 12, color: .white)
                Text(amount)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Theme.card, in: .rect(cornerRadius: 12))
        .overlay(
            ZStack {
                // Track — subtle full-perimeter outline, sits flush inside the card.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 2)

                // Progress arc — represents value / limit, traced along the same perimeter.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .inset(by: 1) // align with strokeBorder so the arc tracks the same path
                    .trim(from: 0, to: progress)
                    .stroke(
                        Theme.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .allowsHitTesting(false)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(amount), \(Int(progress * 100)) percent of limit")
    }
}

// MARK: - Transaction row data.
private struct TxnRowData: Identifiable {
    let id = UUID()
    let kind: Kind
    let title: String
    let timestamp: String
    let amount: String
    var isDollar: Bool = false

    enum Kind { case transfer, arrow }
}

// MARK: - Month section.
private struct MonthSection: View {
    let title: String
    let items: [TxnRowData]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 16) {
                ForEach(items) { item in
                    TxnRow(item: item)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TxnRow: View {
    let item: TxnRowData

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color(red: 0.012, green: 0.004, blue: 0.149)) // #030126
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(item.timestamp)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if !item.isDollar {
                    CurrencyIcon(size: 12, color: .white)
                }
                Text(item.amount)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var iconName: String {
        switch item.kind {
        case .transfer: return "arrow.left.arrow.right"
        case .arrow:    return "arrow.right"
        }
    }
}
