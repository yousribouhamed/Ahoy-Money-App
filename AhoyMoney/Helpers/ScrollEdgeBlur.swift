import SwiftUI

/// Shared scroll-edge blur effect.
///
/// Drives a smooth blur + fade on a view as it scrolls toward the top edge
/// of its containing scroll view (and a softer return as it leaves the bottom).
///
/// Backed by SwiftUI's `scrollTransition(topLeading:bottomTrailing:axis:transition:)`
/// — Apple's per-element transition primitive. Each element's `phase.value`
/// drives the blur radius and opacity:
///
///   * phase.value  ≈ 0   → identity (fully visible)
///   * phase.value  < 0   → going off the top — fade + blur
///   * phase.value  > 0   → entering from the bottom — left as identity here
///                          for a calmer overall feel
///
/// Use on each major content block inside a `ScrollView` for the same look
/// `FillDetailsView` ships with.
extension View {
    func scrollEdgeBlur() -> some View {
        scrollTransition(
            topLeading: .interactive,
            bottomTrailing: .identity,
            axis: .vertical
        ) { content, phase in
            let v = phase.value
            let blurRadius: CGFloat = v < 0 ? min(abs(v) * 14, 14) : 0
            let opacity = v < 0 ? max(1 - abs(v) * 0.6, 0.4) : 1
            return content
                .blur(radius: blurRadius)
                .opacity(opacity)
        }
    }
}
