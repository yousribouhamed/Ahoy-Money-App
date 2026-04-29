import SwiftUI
import UIKit

struct Country: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    var display: String { "\(code) \(name)" }
}

struct CountryCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (Country) -> Void

    @State private var query: String = ""

    private let all: [Country] = [
        .init(code: "+213", name: "Algeria"),
        .init(code: "+23",  name: "Brazil"),
        .init(code: "+11",  name: "Canada"),
        .init(code: "+84",  name: "Denmark"),
        .init(code: "+60",  name: "Egypt"),
        .init(code: "+41",  name: "Finland"),
        .init(code: "+62",  name: "Ghana"),
        .init(code: "+92",  name: "Hungary"),
        .init(code: "+901", name: "India"),
        .init(code: "+34",  name: "Japan"),
        .init(code: "+89",  name: "Kenya"),
        .init(code: "+977", name: "Lebanon"),
        .init(code: "+1",   name: "Mexico"),
        .init(code: "+47",  name: "Norway"),
        .init(code: "+968", name: "Oman"),
        .init(code: "+351", name: "Portugal"),
        .init(code: "+974", name: "Qatar"),
        .init(code: "+7",   name: "Russia"),
        .init(code: "+966", name: "Saudi Arabia"),
        .init(code: "+90",  name: "Turkey"),
        .init(code: "+971", name: "UAE"),
        .init(code: "+44",  name: "United Kingdom"),
        .init(code: "+1",   name: "United States"),
        .init(code: "+84",  name: "Vietnam"),
        .init(code: "+260", name: "Zambia")
    ]

    private var filtered: [Country] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(q) || $0.code.contains(q)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0x05/255, green: 0x01/255, blue: 0x3B/255),
                         Color(red: 0x02/255, green: 0x11/255, blue: 0x22/255)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top toolbar.
                ZStack {
                    Text("Country Code")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(.white)

                        Spacer()

                        Button {
                            // Placeholder action.
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(Color(red: 0x00/255, green: 0x7A/255, blue: 1.0))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)

                // List with native iOS 17+ scrollTransition: each row blurs &
                // fades as it scrolls past the bottom edge, where the liquid-glass
                // search field floats on top.
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { country in
                            Button {
                                onSelect(country)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(country.display)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Theme.subText.opacity(0.6))
                                        .frame(height: 0.5)
                                }
                            }
                            .buttonStyle(.plain)
                            .scrollTransition(
                                topLeading: .identity,
                                bottomTrailing: .interactive,
                                axis: .vertical
                            ) { content, phase in
                                let v = phase.value
                                let blurRadius: CGFloat = v > 0 ? min(v * 14, 14) : 0
                                let opacity = v > 0 ? max(1 - v * 0.7, 0.3) : 1
                                return content
                                    .blur(radius: blurRadius)
                                    .opacity(opacity)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                // Floating liquid-glass search field pinned above the list.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    GlassEffectContainer {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.7))
                            TextField(
                                "",
                                text: $query,
                                prompt: Text("Search").foregroundStyle(.white.opacity(0.7))
                            )
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .tint(.white)
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .font(.system(size: 17))
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

/// True progressive (variable-radius) Gaussian blur using a gradient mask image.
/// Blur radius varies across the view so it eases in — not a uniform blur faded with alpha.
struct VariableBlurView: UIViewRepresentable {
    enum Direction {
        case blurredBottomClearTop
        case blurredTopClearBottom
    }

    var maxBlurRadius: CGFloat = 20
    var direction: Direction = .blurredBottomClearTop

    func makeUIView(context: Context) -> UIView {
        VariableBlurUIView(maxBlurRadius: maxBlurRadius, direction: direction)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class VariableBlurUIView: UIVisualEffectView {
    init(maxBlurRadius: CGFloat, direction: VariableBlurView.Direction) {
        super.init(effect: UIBlurEffect(style: .regular))

        // Find the internal CABackdropLayer so we can attach a CAFilter to it.
        let blurRadiusKey = "inputRadius"
        let maskImageKey = "inputMaskImage"
        let normalizeEdgesKey = "inputNormalizeEdges"

        guard let filterClass = NSClassFromString("CAFilter") as AnyObject as? NSObjectProtocol else { return }
        let filterSelector = NSSelectorFromString("filterWithType:")
        guard filterClass.responds(to: filterSelector),
              let filter = filterClass.perform(filterSelector, with: "variableBlur")?.takeUnretainedValue() as? NSObject
        else { return }

        let gradientImage = VariableBlurUIView.makeGradientMask(direction: direction)
        filter.setValue(maxBlurRadius, forKey: blurRadiusKey)
        filter.setValue(gradientImage, forKey: maskImageKey)
        filter.setValue(true, forKey: normalizeEdgesKey)

        // Replace the default backdrop filters with just our variable blur.
        if let backdropLayer = subviews.first?.layer {
            backdropLayer.filters = [filter]
        }

        // Hide the tint layer so the blur reads cleanly.
        for sub in subviews.dropFirst() {
            sub.alpha = 0
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Disable implicit animations that can cause a flash on appearance.
        guard let window, subviews.indices.contains(1) else { return }
        subviews[1].alpha = 0
        _ = window
    }

    private static func makeGradientMask(direction: VariableBlurView.Direction) -> CGImage? {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors: [CGColor]
            switch direction {
            case .blurredBottomClearTop:
                colors = [UIColor.black.withAlphaComponent(0).cgColor,
                          UIColor.black.cgColor]
            case .blurredTopClearBottom:
                colors = [UIColor.black.cgColor,
                          UIColor.black.withAlphaComponent(0).cgColor]
            }
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space,
                                            colors: colors as CFArray,
                                            locations: [0, 1]) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
        return image.cgImage
    }
}
