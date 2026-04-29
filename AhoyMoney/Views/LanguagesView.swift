import SwiftUI

struct LanguagesView: View {
    @Environment(\.dismiss) private var dismiss

    enum Language: String, CaseIterable, Identifiable {
        case english = "English"
        case arabic  = "Arabic"
        var id: String { rawValue }
    }

    @State private var selected: Language? = nil

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                // Top bar.
                ZStack {
                    Text("Languages")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(.white)

                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 19)
                .padding(.top, 8)

                // Body.
                VStack(alignment: .leading, spacing: 32) {
                    Text("Select your preferred language")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    languageOptionsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var languageOptionsCard: some View {
        let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                languageOptionsContent
                    .glassEffect(.regular, in: cardShape)
            }
        } else {
            languageOptionsContent
                .background(Color.white.opacity(0.2), in: cardShape)
        }
    }

    private var languageOptionsContent: some View {
        VStack(spacing: 16) {
            ForEach(Language.allCases) { lang in
                Button {
                    selected = lang
                } label: {
                    HStack(spacing: 8) {
                        RadioDot(selected: selected == lang)
                        Text(lang.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Radio.
private struct RadioDot: View {
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(selected ? Color(red: 0.09, green: 0.20, blue: 0.33) : Color(red: 0.925, green: 0.937, blue: 0.949))
                .overlay(
                    Circle().strokeBorder(
                        selected ? Color(red: 0.09, green: 0.20, blue: 0.33) : Color(red: 0.4, green: 0.502, blue: 0.569),
                        lineWidth: 1
                    )
                )
            if selected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 16, height: 16)
    }
}
