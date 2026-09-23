import SwiftUI

/// Luma-style onboarding — a 4-page, swipeable, fully-rendered intro flow.
///
/// Research synthesis (Revolut, Wise, Cash App, Coinbase, N26, Lemon Cash, Luma App):
/// • 4 pages: Welcome → Send → Cards → Trust + CTA — the standard fintech narrative
/// • Custom drag-driven pager (not TabView) so we can blend parallax, depth, blur,
///   3D rotation, and a morphing background — Luma's signature look
/// • Each page renders its own programmatic hero (no static art) so transitions
///   feel native to the app and respond to drag progress in real time
/// • Particle field + radial orbs morph their tint per page for ambient depth
/// • Final page exposes Create Account / Login CTAs, intermediate pages have
///   a single Continue button + Skip in the top-right
struct OnboardingView: View {
    @Environment(AppRouter.self) private var router

    @State private var page: Int = 0
    @State private var dragX: CGFloat = 0
    @State private var visiblePage: Double = 0   // continuous index for animation

    private let pages: [OnboardingPage] = [
        .init(
            kind: .welcome,
            eyebrow: "WELCOME",
            title: "Money. Reimagined.",
            body: "AHOY breaks barriers so you can move, save, and grow your money without friction.",
            tint: Theme.accent,
            tintSecondary: Color(red: 0.18, green: 0.36, blue: 0.92)
        ),
        .init(
            kind: .send,
            eyebrow: "SEND",
            title: "Send anywhere, instantly.",
            body: "Wallet-to-wallet, UAE banks, or 200+ countries — one app, every rail.",
            tint: Color(red: 0.62, green: 0.40, blue: 1.00),
            tintSecondary: Color(red: 0.0, green: 0.78, blue: 1.0)
        ),
        .init(
            kind: .cards,
            eyebrow: "CARDS",
            title: "Cards on demand.",
            body: "Spin up virtual cards in seconds. Freeze, customize, and stay in control.",
            tint: Color(red: 1.00, green: 0.55, blue: 0.45),
            tintSecondary: Color(red: 0.95, green: 0.31, blue: 0.66)
        ),
        .init(
            kind: .trust,
            eyebrow: "SECURE",
            title: "Built on trust.",
            body: "Bank-grade encryption. Face ID by default. You're always in the driver's seat.",
            tint: Color(red: 0.20, green: 0.85, blue: 0.65),
            tintSecondary: Theme.accent
        )
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 1. Morphing background — radial orbs that tint per page.
                MorphingBackground(progress: visiblePage, pages: pages)
                    .ignoresSafeArea()

                // 2. Ambient particle field for depth.
                ParticleField(seed: 42)
                    .ignoresSafeArea()
                    .opacity(0.55)

                // 3. Pages — custom drag pager with parallax + 3D.
                ZStack {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        let pageProgress = visiblePage - Double(index)
                        OnboardingPageView(page: page, progress: pageProgress)
                            .frame(width: w, height: h)
                            .offset(x: CGFloat(-pageProgress) * w)
                            .scaleEffect(scale(for: pageProgress))
                            .rotation3DEffect(
                                .degrees(rotation(for: pageProgress)),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: pageProgress < 0 ? .trailing : .leading,
                                perspective: 0.4
                            )
                            .blur(radius: blur(for: pageProgress))
                            .opacity(opacity(for: pageProgress))
                            .allowsHitTesting(abs(pageProgress) < 0.5)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(width: w))

            }
            .frame(width: w, height: h)
            // 4. Skip button (top-right) — iOS 26 liquid glass pill.
            //
            // Anchored as an overlay on the sized frame rather than as a ZStack
            // child: siblings in that stack call `.ignoresSafeArea()`, which
            // widens the stack past the screen, so a trailing inset measured
            // from it pushed the pill off the right edge.
            .overlay(alignment: .topTrailing) {
                Button {
                    jumpToLast()
                } label: {
                    Text("Skip")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.regular)
                .tint(Theme.textPrimary)
                .opacity(page == pages.count - 1 ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: page)
                .padding(.trailing, 19) // right edge aligns with Continue
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 18) {
                PageIndicator(current: visiblePage, total: pages.count)
                bottomCTA
                    .padding(.horizontal, 19) // matches LoginView form padding
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
        }
        .onAppear { visiblePage = Double(page) }
    }

    // MARK: - Drag math (Luma-style)

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                // Rubber-band at the edges so it never feels like it bumps a wall.
                var dx = value.translation.width
                if (page == 0 && dx > 0) || (page == pages.count - 1 && dx < 0) {
                    dx *= 0.35
                }
                dragX = dx
                visiblePage = Double(page) - Double(dx / width)
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width
                let threshold = width * 0.22
                var newPage = page
                if predicted < -threshold && page < pages.count - 1 {
                    newPage = page + 1
                } else if predicted > threshold && page > 0 {
                    newPage = page - 1
                }

                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    page = newPage
                    visiblePage = Double(newPage)
                    dragX = 0
                }
            }
    }

    private func advance() {
        let next = min(page + 1, pages.count - 1)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            page = next
            visiblePage = Double(next)
        }
    }

    private func jumpToLast() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            page = pages.count - 1
            visiblePage = Double(page)
        }
    }

    // Per-page transition modifiers driven by drag progress.
    private func scale(for progress: Double) -> CGFloat {
        1 - CGFloat(min(abs(progress), 1)) * 0.18
    }

    private func rotation(for progress: Double) -> Double {
        Double(min(max(progress, -1), 1)) * -22
    }

    private func blur(for progress: Double) -> CGFloat {
        CGFloat(min(abs(progress), 1)) * 6
    }

    private func opacity(for progress: Double) -> Double {
        1 - min(abs(progress), 1) * 0.6
    }

    // MARK: - Bottom CTA — morphs between Continue and the final pair.

    @ViewBuilder
    private var bottomCTA: some View {
        VStack(spacing: 12) {
            PrimaryWhiteButton(title: "Continue") {
                if page == pages.count - 1 {
                    router.authPath.append(.register)
                } else {
                    advance()
                }
            }
            .shadow(color: Theme.accent.opacity(0.35), radius: 18, y: 4)

            if page == pages.count - 1 {
                Button {
                    router.authPath.append(.login)
                } label: {
                    Text("I already have an account")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: page)
    }
}

// MARK: - Page model

private struct OnboardingPage: Hashable {
    enum Kind { case welcome, send, cards, trust }
    let kind: Kind
    let eyebrow: String
    let title: String
    let body: String
    let tint: Color
    let tintSecondary: Color
}

// MARK: - Page renderer

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let progress: Double   // -1…0…+1 relative to "centered"

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            // Hero visual — parallax: floats further than text.
            heroVisual
                .offset(x: CGFloat(progress) * -60, y: CGFloat(abs(progress)) * 12)
                .frame(maxWidth: .infinity)
                .frame(height: 320)

            Spacer(minLength: 20)

            // Text block — parallax: gentle.
            VStack(alignment: .leading, spacing: 14) {
                Text(page.eyebrow)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(page.tint)

                Text(page.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.body)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .offset(x: CGFloat(progress) * -28)

            Spacer(minLength: 200)
        }
    }

    @ViewBuilder
    private var heroVisual: some View {
        switch page.kind {
        case .welcome: WelcomeOrb(tint: page.tint, tintSecondary: page.tintSecondary, progress: progress)
        case .send:    SendNetwork(tint: page.tint, tintSecondary: page.tintSecondary, progress: progress)
        case .cards:   CardsStack(progress: progress)
        case .trust:   TrustShield(tint: page.tint, tintSecondary: page.tintSecondary, progress: progress)
        }
    }
}

// MARK: - Hero 1: Welcome glass orb with floating ring

private struct WelcomeOrb: View {
    let tint: Color
    let tintSecondary: Color
    let progress: Double

    @State private var rotate: Double = 0

    var body: some View {
        ZStack {
            // Outer glow ring.
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [tint, tintSecondary, tint.opacity(0.2), tint],
                        center: .center
                    ),
                    lineWidth: 1.4
                )
                .frame(width: 280, height: 280)
                .blur(radius: 0.5)
                .rotationEffect(.degrees(rotate))

            // Inner glow ring.
            Circle()
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                .frame(width: 220, height: 220)

            // Glass orb.
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .background(
                        Circle().fill(
                            RadialGradient(
                                colors: [tint.opacity(0.35), .clear],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 4,
                                endRadius: 90
                            )
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: tint.opacity(0.6), radius: 50, y: 12)

                // Currency symbol — uses the project's existing baht glyph.
                Image("currency_baht")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(Theme.textPrimary)
                    .shadow(color: tint.opacity(0.7), radius: 12)
            }
            .frame(width: 160, height: 160)
            .rotation3DEffect(.degrees(progress * 18), axis: (x: 0.4, y: 1, z: 0))

            // Floating sparkles.
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(tintSecondary)
                    .frame(width: 6, height: 6)
                    .blur(radius: 0.5)
                    .offset(
                        x: cos(rotate * .pi / 180 + Double(i) * 1.0) * 130,
                        y: sin(rotate * .pi / 180 + Double(i) * 1.0) * 130
                    )
                    .opacity(0.85)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
                rotate = 360
            }
        }
    }
}

// MARK: - Hero 2: Floating recipient avatars connected by glowing arcs

private struct SendNetwork: View {
    let tint: Color
    let tintSecondary: Color
    let progress: Double

    @State private var pulse: CGFloat = 1.0

    private let avatars: [(String, Color, CGSize, CGFloat)] = [
        ("M", Color(red: 0.88, green: 0.72, blue: 1.00), CGSize(width: -90, height: -60), 56),
        ("Z", Color(red: 1.00, green: 0.85, blue: 0.55), CGSize(width: 95, height: -30), 64),
        ("R", Color(red: 0.66, green: 0.78, blue: 0.92), CGSize(width: -60, height: 80), 52),
        ("A", Color(red: 0.50, green: 0.92, blue: 0.78), CGSize(width: 100, height: 90), 58)
    ]

    var body: some View {
        ZStack {
            // Glowing arcs connecting the central glyph to each avatar.
            ForEach(0..<avatars.count, id: \.self) { i in
                ConnectorLine(
                    end: CGPoint(x: avatars[i].2.width, y: avatars[i].2.height),
                    color: tint
                )
                .opacity(0.5)
            }

            // Central node — sends from your wallet.
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulse)

                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                    .frame(width: 76, height: 76)
                    .shadow(color: tint.opacity(0.6), radius: 24)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            // Outer avatars — each parallaxes at a different depth for the 3D feel.
            ForEach(Array(avatars.enumerated()), id: \.offset) { idx, item in
                let depth = idx % 2 == 0 ? 1.0 : 0.55
                ZStack {
                    Circle()
                        .fill(item.1)
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.4), lineWidth: 1.4)
                        )
                    Text(item.0)
                        .font(.system(size: item.3 * 0.4, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: item.3, height: item.3)
                .shadow(color: item.1.opacity(0.6), radius: 18, y: 6)
                .offset(
                    x: item.2.width + CGFloat(progress) * CGFloat(-30 * depth),
                    y: item.2.height + CGFloat(abs(progress)) * CGFloat(8 * depth)
                )
                .rotation3DEffect(
                    .degrees(progress * 15 * depth),
                    axis: (x: 0.4, y: 1, z: 0)
                )
            }
        }
        .frame(width: 320, height: 320)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = 1.18
            }
        }
    }
}

private struct ConnectorLine: View {
    let end: CGPoint
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let endPoint = CGPoint(x: center.x + end.x, y: center.y + end.y)

            var path = Path()
            path.move(to: center)
            // Quadratic curve with a midpoint nudged outward for a soft bow.
            let mid = CGPoint(
                x: (center.x + endPoint.x) / 2 + (end.y > 0 ? 10 : -10),
                y: (center.y + endPoint.y) / 2
            )
            path.addQuadCurve(to: endPoint, control: mid)

            ctx.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [color, color.opacity(0.0)]),
                    startPoint: center,
                    endPoint: endPoint
                ),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 4])
            )
        }
    }
}

// MARK: - Hero 3: Stacked cards with 3D tilt

private struct CardsStack: View {
    let progress: Double

    private let designs: [CardDesign] = [.aurora, .sunset, .ocean]

    var body: some View {
        ZStack {
            ForEach(Array(designs.enumerated()), id: \.offset) { idx, design in
                let layer = Double(idx)
                let yOffset = -50 + layer * 22
                let xOffset = -10 + layer * 6
                let scale = 1.0 - layer * 0.06

                CardArtworkLite(design: design)
                    .frame(width: 260, height: 162)
                    .scaleEffect(scale)
                    .offset(x: xOffset, y: yOffset)
                    .rotation3DEffect(
                        .degrees(-12 + Double(progress) * 18 + layer * 4),
                        axis: (x: 0.6, y: 1, z: 0)
                    )
                    .rotationEffect(.degrees(-6 + layer * 4))
                    .opacity(0.65 + (1 - layer * 0.25))
                    .shadow(color: design.shadowTint.opacity(0.5), radius: 24, y: 16)
                    .zIndex(Double(designs.count - idx))
            }
        }
        .frame(width: 320, height: 280)
        .offset(y: 20)
    }
}

/// Lightweight card art — just the gradient + chip + brand mark.
/// Avoids pulling the full `CardArtwork` (which depends on a `VirtualCard` instance).
private struct CardArtworkLite: View {
    let design: CardDesign

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(design.gradient)
                .overlay(
                    RadialGradient(
                        colors: [.white.opacity(0.22), .clear],
                        center: UnitPoint(x: 0.18, y: 0.0),
                        startRadius: 4, endRadius: 140
                    )
                    .blendMode(.plusLighter)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.8)
                )

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("AHOY")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(design.foreground)
                    Spacer()
                    // Contactless glyph.
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(design.accent)
                }

                // Chip.
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(design.accent.opacity(0.65))
                    .frame(width: 32, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(design.accent, lineWidth: 0.6)
                    )

                Spacer()

                Text("•••• 4421")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(design.foreground.opacity(0.85))
            }
            .padding(16)
        }
    }
}

// MARK: - Hero 4: Trust shield with concentric rings

private struct TrustShield: View {
    let tint: Color
    let tintSecondary: Color
    let progress: Double

    @State private var ringPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Concentric pulse rings.
            ForEach(0..<3, id: \.self) { i in
                let delay = Double(i) * 0.6
                Circle()
                    .strokeBorder(tint.opacity(0.4 - Double(i) * 0.10), lineWidth: 1)
                    .frame(width: 220 + CGFloat(i) * 50, height: 220 + CGFloat(i) * 50)
                    .scaleEffect(ringPhase)
                    .opacity(2 - Double(ringPhase))
                    .animation(
                        .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(delay),
                        value: ringPhase
                    )
            }

            // Soft halo.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0, endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .blur(radius: 4)

            // Glass shield.
            ZStack {
                ShieldShape()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        ShieldShape()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.25), tintSecondary.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        ShieldShape()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: tint.opacity(0.5), radius: 30, y: 18)

                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .shadow(color: tint, radius: 8)
            }
            .frame(width: 150, height: 180)
            .rotation3DEffect(.degrees(progress * 20), axis: (x: 0, y: 1, z: 0))

            // Floating sparkles around the shield.
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(tintSecondary)
                    .offset(
                        x: cos(Double(i) * .pi / 4) * 130,
                        y: sin(Double(i) * .pi / 4) * 130
                    )
                    .opacity(0.85)
                    .scaleEffect(ringPhase * 0.6 + 0.4)
            }
        }
        .frame(width: 320, height: 320)
        .onAppear {
            ringPhase = 1.6
        }
    }
}

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cornerR: CGFloat = w * 0.22
        // Rounded "shield" silhouette: top arc, taper to bottom point.
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addQuadCurve(
            to: CGPoint(x: w, y: cornerR * 0.6),
            control: CGPoint(x: w * 0.85, y: 0)
        )
        p.addLine(to: CGPoint(x: w, y: h * 0.55))
        p.addQuadCurve(
            to: CGPoint(x: w / 2, y: h),
            control: CGPoint(x: w, y: h * 0.95)
        )
        p.addQuadCurve(
            to: CGPoint(x: 0, y: h * 0.55),
            control: CGPoint(x: 0, y: h * 0.95)
        )
        p.addLine(to: CGPoint(x: 0, y: cornerR * 0.6))
        p.addQuadCurve(
            to: CGPoint(x: w / 2, y: 0),
            control: CGPoint(x: w * 0.15, y: 0)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Morphing background — radial orbs colored per page

private struct MorphingBackground: View {
    let progress: Double
    let pages: [OnboardingPage]

    var body: some View {
        ZStack {
            // Base gradient.
            LinearGradient(
                colors: [Theme.bgTop, Theme.bg],
                startPoint: .top,
                endPoint: .bottom
            )

            // Top-right orb (primary tint).
            Circle()
                .fill(currentTint.opacity(0.55))
                .frame(width: 460, height: 460)
                .blur(radius: 120)
                .offset(x: 140, y: -260)

            // Left orb (secondary tint).
            Circle()
                .fill(currentSecondary.opacity(0.42))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: -160, y: 80)

            // Bottom subtle wash.
            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    /// Interpolates the active page's tint with its neighbour while dragging.
    private var currentTint: Color {
        interpolated(\.tint)
    }

    private var currentSecondary: Color {
        interpolated(\.tintSecondary)
    }

    private func interpolated(_ keyPath: KeyPath<OnboardingPage, Color>) -> Color {
        let clamped = max(0, min(progress, Double(pages.count - 1)))
        let lower = Int(floor(clamped))
        let upper = min(lower + 1, pages.count - 1)
        let t = clamped - Double(lower)
        return blend(pages[lower][keyPath: keyPath], pages[upper][keyPath: keyPath], t: t)
    }

    private func blend(_ a: Color, _ b: Color, t: Double) -> Color {
        let ua = UIColor(a)
        let ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let tt = CGFloat(t)
        return Color(
            red:   Double(r1 + (r2 - r1) * tt),
            green: Double(g1 + (g2 - g1) * tt),
            blue:  Double(b1 + (b2 - b1) * tt),
            opacity: Double(a1 + (a2 - a1) * tt)
        )
    }
}

// MARK: - Particle field

private struct ParticleField: View {
    let seed: UInt64

    @State private var t: TimeInterval = 0

    private struct Particle: Hashable {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let phase: CGFloat
        let speed: CGFloat
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSinceReferenceDate
                var rng = SplitMix64(seed: seed)
                for _ in 0..<60 {
                    let x = CGFloat(rng.next01()) * size.width
                    let y0 = CGFloat(rng.next01()) * size.height
                    let r = 0.8 + CGFloat(rng.next01()) * 1.6
                    let phase = CGFloat(rng.next01()) * .pi * 2
                    let speed = 0.4 + CGFloat(rng.next01()) * 0.8
                    let breathe = sin(now * Double(speed) + Double(phase))
                    let alpha = 0.2 + 0.5 * abs(breathe)
                    let y = y0 + CGFloat(breathe) * 6
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
        }
    }
}

/// Tiny seedable RNG so the particle layout is stable run-to-run
/// without relying on `arc4random` or live state.
private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
    mutating func next01() -> Double {
        Double(next() &>> 11) / Double(UInt64(1) &<< 53)
    }
}

// MARK: - Page indicator (fluid morph)

private struct PageIndicator: View {
    let current: Double
    let total: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                let dist = abs(current - Double(i))
                let isActive = dist < 0.5
                Capsule()
                    .fill(isActive ? Theme.accent : Color.white.opacity(0.25))
                    .frame(
                        width: isActive ? 28 : 7,
                        height: 7
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: current)
            }
        }
    }
}
