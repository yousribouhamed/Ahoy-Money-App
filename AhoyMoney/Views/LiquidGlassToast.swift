import SwiftUI

/// Native iOS 26 liquid glass toast notification.
/// Slides down from the top with a glass-effect capsule, auto-dismisses.
struct LiquidGlassToast: View {
    var icon: String = "checkmark.circle.fill"
    var iconTint: Color = Color(red: 0, green: 0xCD/255, blue: 1)
    var message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconTint)

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// Modifier that overlays a liquid glass toast at the top edge of the screen.
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    var message: String
    var icon: String = "checkmark.circle.fill"
    var duration: TimeInterval = 2.5

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    LiquidGlassToast(icon: icon, message: message)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(duration))
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                isPresented = false
                            }
                        }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isPresented)
    }
}

extension View {
    /// Native iOS 26 liquid glass toast that slides in from the top.
    func liquidGlassToast(
        isPresented: Binding<Bool>,
        message: String,
        icon: String = "checkmark.circle.fill",
        duration: TimeInterval = 2.5
    ) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon, duration: duration))
    }
}
