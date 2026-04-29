import SwiftUI

/// The visual representation of a virtual card.
///
/// Used at three sizes:
/// • **Hero** in detail / success screens (full-width, ~ 0.62 aspect, 3D tilt enabled)
/// • **Carousel** on Home (snappable wide tile)
/// • **Swatch** on the design picker (compact)
///
/// The artwork composes a gradient base, a soft radial highlight, a chip + contactless
/// glyph, the brand logos, the user's name and the masked PAN.
/// When the card is frozen we overlay a translucent ice glass effect with a snowflake.
struct CardArtwork: View {
    let card: VirtualCard

    /// Optional override — use to render a design preview before the user
    /// has issued anything. Defaults to the card's saved design.
    var designOverride: CardDesign? = nil

    /// Height of the chip + brand. Auto-scales to the card width.
    var size: CGSize = CGSize(width: 320, height: 200)

    /// Show CVV / full PAN. Otherwise we mask everything but the last 4.
    var revealed: Bool = false

    /// Soft 3D tilt that follows touch — used on hero only. Defaults to off.
    var tiltEnabled: Bool = false

    @State private var tilt: CGSize = .zero

    private var design: CardDesign { designOverride ?? card.design }

    private var corner: CGFloat { size.width * 0.064 }

    var body: some View {
        ZStack {
            base
            highlight
            content
            frozenOverlay
            blockedOverlay
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .shadow(color: design.shadowTint.opacity(0.45), radius: 18, x: 0, y: 14)
        .rotation3DEffect(
            .degrees(Double(-tilt.height / 12)),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(tilt.width / 12)),
            axis: (x: 0, y: 1, z: 0)
        )
        .gesture(
            tiltEnabled
                ? DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let max: CGFloat = 18
                        tilt = CGSize(
                            width: v.translation.width.clamped(-max, max),
                            height: v.translation.height.clamped(-max, max)
                        )
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                            tilt = .zero
                        }
                    }
                : nil
        )
    }

    // MARK: - Layers

    private var base: some View {
        design.gradient
    }

    /// Soft moving sheen — a radial highlight that subtly travels across the card.
    private var highlight: some View {
        RadialGradient(
            colors: [Color.white.opacity(0.22), Color.white.opacity(0)],
            center: UnitPoint(x: 0.2, y: 0.0),
            startRadius: 4,
            endRadius: size.width * 0.85
        )
        .blendMode(.plusLighter)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row — brand mark + contactless.
            HStack(alignment: .top) {
                Text("AHOY")
                    .font(.system(size: size.width * 0.052, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(design.foreground)

                Spacer()

                Image(systemName: "wave.3.right")
                    .font(.system(size: size.width * 0.052, weight: .semibold))
                    .foregroundStyle(design.foreground.opacity(0.85))
                    .rotationEffect(.degrees(0))
            }

            Spacer()

            // Chip + label band.
            HStack(spacing: 10) {
                ChipGlyph(accent: design.accent)
                    .frame(width: size.width * 0.10, height: size.width * 0.075)

                Text(card.label.uppercased())
                    .font(.system(size: size.width * 0.034, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(design.foreground.opacity(0.7))
                    .lineLimit(1)
                    .frame(maxWidth: size.width * 0.45, alignment: .leading)
            }

            Spacer()

            // PAN.
            Text(revealed ? card.formattedNumber : "•••• •••• •••• \(card.last4)")
                .font(.system(size: size.width * 0.055, weight: .semibold, design: .rounded))
                .foregroundStyle(design.foreground)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Bottom row.
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CARDHOLDER")
                        .font(.system(size: size.width * 0.025, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(design.foreground.opacity(0.55))
                    Text(card.cardholderName)
                        .font(.system(size: size.width * 0.034, weight: .semibold))
                        .foregroundStyle(design.foreground)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("EXPIRES")
                        .font(.system(size: size.width * 0.025, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(design.foreground.opacity(0.55))
                    Text(card.expiry)
                        .font(.system(size: size.width * 0.034, weight: .semibold))
                        .foregroundStyle(design.foreground)
                        .monospacedDigit()
                }
                .padding(.trailing, 8)

                // Visa-style brand mark — drawn rather than imported so it stays sharp.
                NetworkMark(color: design.foreground)
                    .frame(width: size.width * 0.16, height: size.width * 0.06)
            }
        }
        .padding(.horizontal, size.width * 0.06)
        .padding(.vertical, size.width * 0.06)
    }

    @ViewBuilder
    private var frozenOverlay: some View {
        if card.status == .frozen {
            ZStack {
                // Frosted glass overlay.
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.85)
                LinearGradient(
                    colors: [Color(red: 0.74, green: 0.93, blue: 1.0).opacity(0.35), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Snowflake badge.
                VStack(spacing: 4) {
                    Image(systemName: "snowflake")
                        .font(.system(size: size.width * 0.13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 0.85))
                    Text("FROZEN")
                        .font(.system(size: size.width * 0.034, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Color(red: 0.3, green: 0.45, blue: 0.7))
                }
            }
            .transition(.opacity.combined(with: .scale))
        }
    }

    @ViewBuilder
    private var blockedOverlay: some View {
        if card.status == .blocked {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.55))

                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size.width * 0.13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("BLOCKED")
                        .font(.system(size: size.width * 0.034, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Chip glyph

/// Stylised EMV chip — gold-ish gradient with grid lines drawn in stroke.
private struct ChipGlyph: View {
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let r: CGFloat = 4
            ZStack {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.9),
                                accent.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Gold lines.
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    // Vertical centre.
                    path.move(to: CGPoint(x: w / 2, y: 0))
                    path.addLine(to: CGPoint(x: w / 2, y: h))
                    // Horizontal centre.
                    path.move(to: CGPoint(x: 0, y: h / 2))
                    path.addLine(to: CGPoint(x: w, y: h / 2))
                    // Top quarter horizontals.
                    path.move(to: CGPoint(x: 0, y: h * 0.25))
                    path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.25))
                    path.move(to: CGPoint(x: w * 0.7, y: h * 0.25))
                    path.addLine(to: CGPoint(x: w, y: h * 0.25))
                    // Bottom quarter horizontals.
                    path.move(to: CGPoint(x: 0, y: h * 0.75))
                    path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.75))
                    path.move(to: CGPoint(x: w * 0.7, y: h * 0.75))
                    path.addLine(to: CGPoint(x: w, y: h * 0.75))
                }
                .stroke(Color.black.opacity(0.35), lineWidth: 0.6)
            }
        }
    }
}

// MARK: - Network mark

/// Stylised Visa-like wordmark.
private struct NetworkMark: View {
    let color: Color

    var body: some View {
        Text("VISA")
            .font(.system(size: 18, weight: .heavy, design: .serif))
            .italic()
            .tracking(1)
            .foregroundStyle(color)
            .scaledToFit()
            .minimumScaleFactor(0.4)
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}
