import SwiftUI
import UIKit

// MARK: - Adaptive color helper

/// Wraps a (light, dark) pair into a `Color` that automatically swaps based
/// on the active trait collection. Keeps the rest of the codebase agnostic
/// of which mode it's running in.
private func adaptive(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

private extension UIColor {
    /// Convenience to keep the call-sites readable.
    static func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Theme

enum Theme {
    // Backgrounds — dark stays inky navy, light is a soft cool gray-white.
    static let bg = adaptive(
        light: .rgb(0.95, 0.96, 0.98),    // #F2F4F8
        dark:  .rgb(0.008, 0.067, 0.133)  // #021122
    )
    static let bgTop = adaptive(
        light: .rgb(1.00, 1.00, 1.00),    // #FFFFFF
        dark:  .rgb(0.020, 0.004, 0.231)  // #05013B
    )
    static let card = adaptive(
        light: .rgb(1.00, 1.00, 1.00),    // #FFFFFF
        dark:  .rgb(0.020, 0.176, 0.345)  // #052D58
    )
    static let glow = adaptive(
        light: .rgb(0.55, 0.75, 1.00, 0.4),
        dark:  .rgb(0.180, 0.357, 0.722)
    )
    static let deepGlow = adaptive(
        light: .rgb(0.85, 0.92, 1.00, 0.35),
        dark:  .rgb(0.039, 0.122, 0.322)
    )

    // Brand accent — cyan in dark, deeper teal in light for proper WCAG AA on white.
    static let accent = adaptive(
        light: .rgb(0.00, 0.48, 0.62),    // #007A9E — 4.7:1 on white
        dark:  .rgb(0.000, 0.816, 1.000)  // #00D0FF
    )
    /// Color used for text/icons drawn ON TOP of `accent` backgrounds.
    static let accentDeep = adaptive(
        light: .rgb(1.00, 1.00, 1.00),    // white text on accent in light
        dark:  .rgb(0.000, 0.129, 0.161)  // dark navy text on accent in dark
    )

    // Text — primary always passes 7:1 contrast on bg.
    static let textPrimary = adaptive(
        light: .rgb(0.06, 0.09, 0.16),    // near-black
        dark:  .rgb(1.00, 1.00, 1.00)     // white
    )
    static let textSecondary = adaptive(
        light: .rgb(0.36, 0.40, 0.46),    // 4.6:1 on white
        dark:  .rgb(1.0, 1.0, 1.0, 0.7)   // 70% white
    )
    static let subText = adaptive(
        light: .rgb(0.27, 0.42, 0.58),    // mid blue-gray
        dark:  .rgb(0.380, 0.627, 0.890)  // sky blue
    )

    // Hairline / divider.
    static let divider = adaptive(
        light: .rgb(0.90, 0.91, 0.94),
        dark:  .rgb(1.0, 1.0, 1.0, 0.06)
    )

    // Tertiary text — for placeholder, hints, faint captions.
    static let textTertiary = adaptive(
        light: .rgb(0.55, 0.58, 0.64),    // subdued gray
        dark:  .rgb(1.0, 1.0, 1.0, 0.55)
    )

    // Subtle glass overlay on top of cards (was Color.white.opacity(0.06)).
    static let cardOverlay = adaptive(
        light: .rgb(0.0, 0.0, 0.0, 0.04),
        dark:  .rgb(1.0, 1.0, 1.0, 0.06)
    )

    // Slightly stronger glass overlay (was Color.white.opacity(0.10)).
    static let cardOverlayHigh = adaptive(
        light: .rgb(0.0, 0.0, 0.0, 0.06),
        dark:  .rgb(1.0, 1.0, 1.0, 0.10)
    )

    // Hairline border (was Color.white.opacity(0.12)).
    static let strokeSubtle = adaptive(
        light: .rgb(0.0, 0.0, 0.0, 0.10),
        dark:  .rgb(1.0, 1.0, 1.0, 0.12)
    )

    // Accents.
    static let warning       = Color(red: 0.992, green: 0.780, blue: 0.000)   // #FDC700
    static let iosBlue       = Color(red: 0.000, green: 0.478, blue: 1.000)   // #007AFF

    // Misc legacy slots — kept stable across modes.
    static let ink           = Color(red: 0.121, green: 0.137, blue: 0.173)
    static let inkDeep       = Color(red: 0.035, green: 0.035, blue: 0.043)
    static let grayText      = Color(red: 0.451, green: 0.451, blue: 0.451)
    static let grayBorder    = Color(red: 0.831, green: 0.831, blue: 0.831)
    static let grayBorderLight = Color(red: 0.898, green: 0.898, blue: 0.898)
    static let grayBg        = Color(red: 0.961, green: 0.961, blue: 0.961)
    static let grayHandle    = Color(red: 0.757, green: 0.757, blue: 0.757)
    static let disabled      = Color(red: 0.302, green: 0.298, blue: 0.310)
}

// MARK: - Adaptive gradient background

/// App-wide background. Renamed semantics: still called `DarkGradientBackground`
/// for source-compat with existing call sites, but it now adapts to the active
/// color scheme — dark navy + glow in dark mode, soft white-to-mist in light.
struct DarkGradientBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [Theme.bgTop, Theme.bg]
                    : [Theme.bgTop, Theme.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            // Radial glow — bright cyan halo in dark, soft sky tint in light.
            RadialGradient(
                colors: scheme == .dark
                    ? [
                        Theme.glow.opacity(0.6),
                        Theme.deepGlow.opacity(0.28),
                        Theme.bg.opacity(0)
                      ]
                    : [
                        Theme.glow.opacity(0.45),
                        Theme.deepGlow.opacity(0.18),
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
