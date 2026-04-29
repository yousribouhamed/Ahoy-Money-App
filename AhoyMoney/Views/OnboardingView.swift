import SwiftUI

struct OnboardingView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Figma frame is 402 x 874.
            let sx = w / 402
            let sy = h / 874

            ZStack(alignment: .topLeading) {
                Image("onboarding_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()

                // Bottom gradient overlay — 465pt tall from bottom.
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 465 * sy)
                }

                // Text block at top: 545, left: 32, width: 320.
                VStack(alignment: .leading, spacing: 16) {
                    (Text("Onwards")
                        .foregroundStyle(.white)
                     + Text(".")
                        .foregroundStyle(Theme.accent))
                        .font(.system(size: 34, weight: .bold))

                    Text("AHOY Money breaks barriers  so you can\nbuild wealth effortlessly.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    PaginationIndicator()
                        .padding(.top, 4)
                }
                .frame(width: 320 * sx, alignment: .leading)
                .offset(x: 32 * sx, y: 545 * sy)

                // Buttons at top: 701, centered horizontally, width: 344.
                VStack(spacing: 12) {
                    PrimaryWhiteButton(title: "Create Account") {
                        router.authPath.append(.register)
                    }

                    Button {
                        router.authPath.append(.login)
                    } label: {
                        Text("Login")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 344 * sx)
                .offset(x: (w - 344 * sx) / 2, y: 701 * sy)
            }
            .frame(width: w, height: h)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct PaginationIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 0.0, green: 0x64/255.0, blue: 0x7A/255.0))
                    .frame(width: 29, height: 6)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 13, height: 6)
            }
            Circle()
                .fill(Color(red: 0.0, green: 0x64/255.0, blue: 0x7A/255.0))
                .frame(width: 6, height: 6)
            Circle()
                .fill(Color(red: 0.0, green: 0x64/255.0, blue: 0x7A/255.0))
                .frame(width: 6, height: 6)
        }
    }
}
