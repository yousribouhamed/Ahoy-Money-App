import SwiftUI
import UIKit

// MARK: - scrollEdgeBlur

/// Disables iOS 26's default soft fade at the top edge of a scroll view —
/// that's the "per-element" blur effect the user explicitly didn't want.
///
/// Apply once per `ScrollView`. Used together with `headerBlurBackground()`
/// so the only blur the user sees is a clean fixed-height band behind the
/// title header.
extension View {
    func scrollEdgeBlur(height: CGFloat = 90) -> some View {
        self.scrollEdgeEffectStyle(nil, for: .top)
    }
}

// MARK: - headerBlurBackground

/// Frosted-glass band behind a screen's title header.
///
/// Apply to the `topBar` content placed inside `.safeAreaInset(edge: .top)`.
/// The blur extends UP into the status-bar area via `.ignoresSafeArea(.top)`,
/// so as the user scrolls, content slides under a clean fixed-height band
/// — the same behaviour Apple's `Navigation Bar` ships with.
///
/// Uses a UIKit `UIVisualEffectView` (the same primitive nav bars use) for
/// reliable blur on dark backgrounds — SwiftUI's `.ultraThinMaterial` renders
/// inconsistently against gradients.
extension View {
    func headerBlurBackground() -> some View {
        self.background {
            // Variable-radius Gaussian blur — same primitive used in
            // CountryCodeSheet's bottom band. Solid blur at the top of
            // the band, easing to clear at the bottom.
            //
            // We ALSO mask the whole layer to fade visual opacity to 0
            // at the bottom edge so the band has no hard cutoff against
            // the content scrolling below it.
            VariableBlurView(
                maxBlurRadius: 20,
                direction: .blurredTopClearBottom
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.55),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - UIBlurView

/// UIKit blur — the same primitive nav bars / tab bars use.
private struct UIBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
