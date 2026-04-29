import Foundation
import SwiftUI

@Observable
final class WalletStore {
    var balance: Double = 1245.00
    var isAccountVerified: Bool = false

    static func formatMoney(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

@Observable
final class AppRouter {
    enum Route: Hashable {
        case login
        case register
        case verifyOtp
        case setupWallet
        case scanID
        case scanIDBack
        case selfieIntro
        case selfieCapture
        case verifyingIdentity
        case fillDetails
        case createPassword
        case walletCreated
        case forgetPassword
        case resetPassword
    }

    enum Tab: Hashable { case wallet, send, transactions, settings }

    var authPath: [Route] = []
    var isAuthenticated: Bool = false
    var selectedTab: Tab = .wallet
}
