import SwiftUI

enum Theme {
    static let bg            = Color(red: 0.008, green: 0.067, blue: 0.133)   // #021122
    static let bgTop         = Color(red: 0.020, green: 0.004, blue: 0.231)   // #05013B
    static let card          = Color(red: 0.020, green: 0.176, blue: 0.345)   // #052D58
    static let glow          = Color(red: 0.180, green: 0.357, blue: 0.722)   // #2E5BB8
    static let deepGlow      = Color(red: 0.039, green: 0.122, blue: 0.322)   // #0A1F52
    static let accent        = Color(red: 0.000, green: 0.816, blue: 1.000)   // #00D0FF
    static let accentDeep    = Color(red: 0.000, green: 0.129, blue: 0.161)   // #002129
    static let subText       = Color(red: 0.380, green: 0.627, blue: 0.890)   // #61A0E3
    static let warning       = Color(red: 0.992, green: 0.780, blue: 0.000)   // #FDC700
    static let iosBlue       = Color(red: 0.000, green: 0.478, blue: 1.000)   // #007AFF
    static let ink           = Color(red: 0.121, green: 0.137, blue: 0.173)   // #1F232C
    static let inkDeep       = Color(red: 0.035, green: 0.035, blue: 0.043)   // #09090B
    static let grayText      = Color(red: 0.451, green: 0.451, blue: 0.451)   // #737373
    static let grayBorder    = Color(red: 0.831, green: 0.831, blue: 0.831)   // #D4D4D4
    static let grayBorderLight = Color(red: 0.898, green: 0.898, blue: 0.898) // #E5E5E5
    static let grayBg        = Color(red: 0.961, green: 0.961, blue: 0.961)   // #F5F5F5
    static let grayHandle    = Color(red: 0.757, green: 0.757, blue: 0.757)   // #C1C1C1
    static let disabled      = Color(red: 0.302, green: 0.298, blue: 0.310)   // #4D4C4F
}

struct DarkGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.bgTop, Theme.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Theme.glow.opacity(0.6),
                    Theme.deepGlow.opacity(0.28),
                    Theme.bg.opacity(0)
                ],
                center: UnitPoint(x: 0.88, y: -0.02),
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}
