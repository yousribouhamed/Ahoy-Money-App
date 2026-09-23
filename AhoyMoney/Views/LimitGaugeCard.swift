import SwiftUI

/// Half-circle gauge card with a draggable knob.
/// Drag the cyan knob along the arc to set a value from `minValue` to `maxValue`.
struct LimitGaugeCard: View {
    var title: String
    @Binding var value: Double
    var minValue: Double = 0
    var maxValue: Double = 100_000
    /// Unfilled part of the arc. Defaults to white for the dark screens; the
    /// white bottom sheets pass a light grey so the track is visible.
    var trackColor: Color = .white
    /// Centre value + title colour, for the same reason.
    var labelColor: Color = Theme.textPrimary

    private var progress: Double {
        let clamped = min(max(value, minValue), maxValue)
        return (clamped - minValue) / (maxValue - minValue)
    }

    /// Half of the knob plus a hair, so the knob never clips at the arc ends.
    private static let inset: CGFloat = 13
    private static let gaugeHeight: CGFloat = 118

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                // Radius comes from the height, so the bowl always fits the box
                // it's given. The old `min(width, height * 2)` produced a centre
                // below the box, which is why the value sat on top of the title.
                let radius = geo.size.height - Self.inset
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height - 1)
                let strokeWidth: CGFloat = 12
                let knobSize: CGFloat = 22

                ZStack {
                    // Background (white) arc — 180°→0°.
                    Path { p in
                        p.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(180),
                            endAngle: .degrees(360),
                            clockwise: false
                        )
                    }
                    .stroke(trackColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

                    // Filled (cyan) arc — 180°→ angle.
                    Path { p in
                        p.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(180),
                            endAngle: .degrees(180 + 180 * progress),
                            clockwise: false
                        )
                    }
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

                    // Knob.
                    let theta = Angle.degrees(180 + 180 * progress).radians
                    let knobX = center.x + radius * cos(theta)
                    let knobY = center.y + radius * sin(theta)
                    Circle()
                        .fill(Theme.accent)
                        .overlay(
                            Circle()
                                .strokeBorder(trackColor, lineWidth: 3)
                        )
                        .frame(width: knobSize, height: knobSize)
                        .position(x: knobX, y: knobY)

                    // Value and caption together, seated inside the bowl where
                    // there is room for both. They used to be separate views —
                    // the value floating below the arc and the caption below
                    // the gauge — and they collided.
                    VStack(spacing: 1) {
                        HStack(spacing: 4) {
                            CurrencyIcon(size: 14, color: labelColor)
                            Text(formatted)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(labelColor)
                                .monospacedDigit()
                        }
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .position(x: geo.size.width / 2, y: center.y - radius * 0.42)
                }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { dragValue in
                            updateValue(from: dragValue.location, center: center)
                        }
                )
            }
            .frame(height: Self.gaugeHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
    }

    private var formatted: String {
        let v = Int(value.rounded())
        if v >= 1000 {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = ","
            return f.string(from: NSNumber(value: v)) ?? "\(v)"
        }
        return "\(v)"
    }

    private func updateValue(from point: CGPoint, center: CGPoint) {
        let dx = point.x - center.x
        let dy = point.y - center.y
        // Standard atan2: returns -π … π; we want angle measured from positive
        // x-axis going clockwise (since SwiftUI y grows downward).
        var angle = atan2(dy, dx) // -π … π
        // We only care about the upper half: angle in [-π, 0] for points above
        // center. If the user drags below center, snap to nearest end.
        if angle > 0 {
            // Below the arc — pick closest extreme.
            angle = (point.x < center.x) ? -.pi : 0
        }
        // Convert to progress: -π → 0, 0 → 1.
        let p = (angle + .pi) / .pi
        let clamped = min(max(p, 0), 1)
        value = minValue + clamped * (maxValue - minValue)
    }
}
