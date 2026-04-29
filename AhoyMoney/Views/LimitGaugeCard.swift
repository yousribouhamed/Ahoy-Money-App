import SwiftUI

/// Half-circle gauge card with a draggable knob.
/// Drag the cyan knob along the arc to set a value from `minValue` to `maxValue`.
struct LimitGaugeCard: View {
    var title: String
    @Binding var value: Double
    var minValue: Double = 0
    var maxValue: Double = 100_000

    private var progress: Double {
        let clamped = min(max(value, minValue), maxValue)
        return (clamped - minValue) / (maxValue - minValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height * 2)
                let radius = size / 2 - 14
                let center = CGPoint(x: geo.size.width / 2, y: radius + 14)
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
                    .stroke(Color.white, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

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
                                .strokeBorder(Color.white, lineWidth: 3)
                        )
                        .frame(width: knobSize, height: knobSize)
                        .position(x: knobX, y: knobY)

                    // Center value.
                    HStack(spacing: 2) {
                        CurrencyIcon(size: 13, color: .white)
                        Text(formatted)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .position(x: geo.size.width / 2, y: center.y + 8)
                }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { dragValue in
                            updateValue(from: dragValue.location, center: center)
                        }
                )
            }
            .frame(height: 110)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 4)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
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
