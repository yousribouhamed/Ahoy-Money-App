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

    /// Turn the card over. The security code lives on the back, where it lives
    /// on a real card, so there is nowhere on the front for a shoulder-surfer
    /// or a screenshot to catch it next to the number.
    var flipped: Bool = false

    /// Name + status printed on the card itself. The detail screen used to
    /// carry these in a separate row under the artwork, which read as a label
    /// for the balance below it rather than for the card above it.
    var showsIdentity: Bool = false

    @State private var tilt: CGSize = .zero

    private var design: CardDesign { designOverride ?? card.design }

    private var corner: CGFloat { size.width * 0.064 }

    var body: some View {
        ZStack {
            // Two faces stacked, each hidden past the halfway point of the
            // turn, so you never see the far side bleeding through.
            face(front: true)
                .opacity(flipped ? 0 : 1)

            face(front: false)
                // Pre-rotated, otherwise the back renders mirrored once the
                // parent has spun the whole card through 180°.
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .frame(width: size.width, height: size.height)
        .rotation3DEffect(
            .degrees(flipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
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
                // Was `minimumDistance: 0`, which swallowed every tap before it
                // could reach the flip. The tilt now waits for an actual drag.
                ? DragGesture(minimumDistance: 12)
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

    private func face(front: Bool) -> some View {
        ZStack {
            base
            facets
            highlight
            if front { content } else { backContent }
            frozenOverlay
            blockedOverlay
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    // MARK: - Layers

    private var base: some View {
        design.gradient
    }

    /// Low-poly facet treatment, drawn over the gradient.
    ///
    /// Cell size scales with the card so density reads the same on the 340pt
    /// hero and the 60pt list thumbnail.
    private var facets: some View {
        FacetPattern(seed: Self.seed(for: card.id), cell: size.width / 9)
    }

    /// Stable seed from the card's UUID.
    ///
    /// Deliberately not `hashValue` — Swift seeds that randomly per process, so
    /// the pattern would reshuffle on every launch and the same card would look
    /// like a different one.
    private static func seed(for id: UUID) -> UInt64 {
        withUnsafeBytes(of: id.uuid) { $0.load(as: UInt64.self) }
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
        ZStack {
            // Chip + card number, laid out as its own centred layer rather than
            // as a row between the others. Sitting it in the stack made its
            // position depend on how tall the rows above and below happened to
            // be; this way it's always on the card's true vertical centre.
            HStack(spacing: 12) {
                ChipGlyph(accent: design.accent)
                    .frame(width: size.width * 0.10, height: size.width * 0.075)

                Text(revealed ? card.formattedNumber : "•••• •••• •••• \(card.last4)")
                    .font(.system(size: size.width * 0.05, weight: .semibold, design: .rounded))
                    .foregroundStyle(design.foreground)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Top row — brand mark + contactless.
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: size.width * 0.012) {
                        Text("AHOY")
                            .font(.system(size: size.width * 0.052, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(design.foreground)

                        if showsIdentity {
                            HStack(spacing: size.width * 0.018) {
                                Text(card.label)
                                    .font(.system(size: size.width * 0.038, weight: .semibold))
                                    .foregroundStyle(design.foreground.opacity(0.9))
                                    .lineLimit(1)

                                Circle()
                                    .fill(card.status == .frozen
                                          ? Color(red: 0.40, green: 0.65, blue: 1.00)
                                          : Color(red: 0.30, green: 0.85, blue: 0.55))
                                    .frame(width: size.width * 0.017, height: size.width * 0.017)

                                Text(card.status == .frozen ? "FROZEN" : "ACTIVE")
                                    .font(.system(size: size.width * 0.026, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundStyle(design.foreground.opacity(0.7))
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "wave.3.right")
                        .font(.system(size: size.width * 0.052, weight: .semibold))
                        .foregroundStyle(design.foreground.opacity(0.85))
                        .rotationEffect(.degrees(0))
                }

                Spacer(minLength: 0)

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

                // Visa brand mark. Width-only frame so the height follows the
                // logo's own aspect rather than being letterboxed into a box.
                NetworkMark(color: design.foreground)
                    .frame(width: size.width * 0.16)
                }
            }
        }
        .padding(.horizontal, size.width * 0.06)
        .padding(.vertical, size.width * 0.06)
    }

    /// The back of the card: magnetic stripe, signature panel, security code.
    ///
    /// Laid out like the real thing on purpose — the reason a flip needs no
    /// caption is that everyone already knows the code lives back here.
    private var backContent: some View {
        VStack(spacing: 0) {
            // Magnetic stripe, full bleed.
            Rectangle()
                .fill(Color.black.opacity(0.72))
                .frame(height: size.width * 0.135)
                .padding(.top, size.width * 0.075)

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: size.width * 0.03) {
                // Signature panel — the pale strip a real code is printed beside.
                RoundedRectangle(cornerRadius: size.width * 0.008, style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .frame(height: size.width * 0.08)
                    .overlay(alignment: .leading) {
                        Text(card.cardholderName)
                            .font(.system(size: size.width * 0.028, weight: .regular, design: .serif))
                            .foregroundStyle(.black.opacity(0.45))
                            .padding(.leading, size.width * 0.025)
                            .lineLimit(1)
                    }

                VStack(alignment: .leading, spacing: size.width * 0.004) {
                    Text("CVV")
                        .font(.system(size: size.width * 0.025, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(design.foreground.opacity(0.55))
                    Text(revealed ? card.cvv : "•••")
                        .font(.system(size: size.width * 0.045, weight: .bold, design: .monospaced))
                        .foregroundStyle(design.foreground)
                }
                .frame(width: size.width * 0.16, alignment: .leading)
            }
            .padding(.horizontal, size.width * 0.06)

            Spacer(minLength: 0)

            // Expiry repeats here so the back alone is enough to fill a
            // checkout form — flipping back for two digits is the whole reason
            // split card details annoy people.
            HStack(spacing: size.width * 0.02) {
                Text("EXPIRES")
                    .font(.system(size: size.width * 0.025, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(design.foreground.opacity(0.55))
                Text(card.expiry)
                    .font(.system(size: size.width * 0.03, weight: .semibold, design: .monospaced))
                    .foregroundStyle(design.foreground.opacity(0.9))

                Spacer(minLength: 0)

                Text(revealed ? card.formattedNumber : "•••• \(card.last4)")
                    .font(.system(size: size.width * 0.03, weight: .semibold, design: .monospaced))
                    .foregroundStyle(design.foreground.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, size.width * 0.06)
            .padding(.bottom, size.width * 0.06)
        }
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
                    colors: [Color(red: 0.74, green: 0.93, blue: 1.0).opacity(0.35), Theme.cardOverlayHigh],
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
        if card.status == .expired {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.55))

                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: size.width * 0.13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("EXPIRED")
                        .font(.system(size: size.width * 0.034, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Theme.textPrimary)
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

/// Visa wordmark.
///
/// Vector asset with `template-rendering-intent`, so it takes the card design's
/// foreground colour — dark on the light designs, white on the rest.
private struct NetworkMark: View {
    let color: Color

    var body: some View {
        Image("visa_logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self {
        min(max(self, lo), hi)
    }
}

// MARK: - Facet pattern

/// Low-poly facet overlay — a square grid where each cell is split on one
/// diagonal or the other, and each resulting triangle is shaded slightly
/// lighter or darker than its neighbours.
///
/// Facets are neutral white/black at low alpha rather than fixed colours, so
/// the pattern inherits whichever design gradient sits underneath and works
/// across all eight without needing a palette per design. Alpha is kept low on
/// purpose: the card number and cardholder name sit on top of this, and a
/// stronger treatment costs legibility.
/// Shared with the design picker so a swatch previews what you actually get.
struct FacetPattern: View {
    let seed: UInt64
    let cell: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            var rng = FacetRandom(seed: seed)
            let cols = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * cell
                    let y = CGFloat(row) * cell

                    let topLeft     = CGPoint(x: x,        y: y)
                    let topRight    = CGPoint(x: x + cell, y: y)
                    let bottomRight = CGPoint(x: x + cell, y: y + cell)
                    let bottomLeft  = CGPoint(x: x,        y: y + cell)

                    // Alternate which diagonal splits the cell.
                    let split = rng.nextBool()
                    let first  = split ? [topLeft, topRight, bottomRight]
                                       : [topLeft, topRight, bottomLeft]
                    let second = split ? [topLeft, bottomRight, bottomLeft]
                                       : [topRight, bottomRight, bottomLeft]

                    for triangle in [first, second] {
                        var path = Path()
                        path.move(to: triangle[0])
                        path.addLine(to: triangle[1])
                        path.addLine(to: triangle[2])
                        path.closeSubpath()
                        context.fill(path, with: .color(shade(&rng)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func shade(_ rng: inout FacetRandom) -> Color {
        let t = rng.nextDouble()
        return t < 0.5
            ? Color.white.opacity(0.02 + t * 0.14)
            : Color.black.opacity(0.02 + (t - 0.5) * 0.12)
    }
}

/// Small deterministic generator, so a card's facets are identical every time
/// it's drawn.
/// File-scoped so it can't clash with the onboarding particle field's own generator.
private struct FacetRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextBool() -> Bool { next() & 1 == 0 }
}
