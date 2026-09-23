import SwiftUI

/// Full-screen live chat with Ahoy support.
///
/// Research-informed (Revolut, Wise, Monzo, N26, Nubank, Cash App):
/// • Agent identity + online status pinned to the top bar
/// • Message bubbles — left-aligned for agent/bot, right-aligned for user
/// • System pills for "now connected with…" / "agent transferred"
/// • Quick-reply chips above the input — bot/agent can suggest answers
/// • "Typing…" indicator with three animated dots
/// • Day-grouped time separators
/// • Glass capsule input with attach + mic + send
///
/// `ChatStore` owns the messages and a tiny intent matcher to simulate the
/// agent's replies — drop-in replaceable with a real WebSocket later.
struct LiveChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ChatStore.self) private var store

    @State private var draft: String = ""
    @State private var showEndConfirm: Bool = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            DarkGradientBackground()

            VStack(spacing: 0) {
                conversation
                    .scrollEdgeBlur()
                quickReplyBar
                inputBar
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
                .padding(.horizontal, 19)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .headerBlurBackground()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.hasUnread = false }
        .confirmationDialog(
            "End this chat?",
            isPresented: $showEndConfirm,
            titleVisibility: .visible
        ) {
            Button("End chat", role: .destructive) {
                store.reset()
                dismiss()
            }
            Button("Keep chatting", role: .cancel) {}
        } message: {
            Text("Your conversation will be cleared. Past tickets stay on your account.")
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(store.agent.avatarBg)
                    Text(store.agent.avatarInitial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 32, height: 32)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(store.agent.isOnline
                              ? Color(red: 0.34, green: 0.85, blue: 0.55)
                              : Color.white.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 2))
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(store.agent.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(store.isAgentTyping ? "typing…" : (store.agent.isOnline ? "Online" : "Away"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(store.isAgentTyping ? Theme.accent : .white.opacity(0.55))
                }
            }

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)

                Spacer()

                Menu {
                    Button {
                        // call shortcut
                        if let url = URL(string: "tel:+97180024699") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Call us instead", systemImage: "phone.fill")
                    }
                    Button {
                        if let url = URL(string: "mailto:help@ahoy.ae") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Email support", systemImage: "envelope.fill")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showEndConfirm = true
                    } label: {
                        Label("End chat", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.white)
            }
        }
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.messages) { msg in
                        switch msg.role {
                        case .system:
                            SystemBubble(text: msg.text)
                                .id(msg.id)
                        case .user:
                            HStack {
                                Spacer(minLength: 60)
                                MessageBubble(message: msg, alignment: .trailing)
                            }
                            .id(msg.id)
                        case .agent, .bot:
                            HStack(alignment: .top, spacing: 8) {
                                AgentAvatar(agent: store.agent)
                                MessageBubble(message: msg, alignment: .leading)
                                Spacer(minLength: 60)
                            }
                            .id(msg.id)
                        }
                    }

                    if store.isAgentTyping {
                        HStack(alignment: .top, spacing: 8) {
                            AgentAvatar(agent: store.agent)
                            TypingIndicator()
                            Spacer(minLength: 60)
                        }
                        .id("typing")
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.messages.count) { _, _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    if let last = store.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: store.isAgentTyping) { _, isTyping in
                if isTyping {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = store.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Quick replies

    @ViewBuilder
    private var quickReplyBar: some View {
        let lastQuickReplies = store.messages.last?.quickReplies ?? []
        if !lastQuickReplies.isEmpty && !store.isAgentTyping {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lastQuickReplies, id: \.self) { reply in
                        Button { send(reply) } label: {
                            Text(reply)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.accent.opacity(0.12), in: .capsule)
                                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .scrollClipDisabled()
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                // Stub: attach action.
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $draft,
                    prompt: Text("Message support…").foregroundStyle(Theme.textSecondary),
                    axis: .vertical
                )
                .focused($inputFocused)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .tint(.white)
                .submitLabel(.send)
                .onSubmit { sendDraft() }

                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)

            // Send button — only enabled when draft has content.
            let canSend = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(canSend ? Theme.accentDeep : .white.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(canSend ? Theme.accent : Theme.cardOverlay, in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .padding(.top, 6)
    }

    // MARK: - Helpers

    private func sendDraft() {
        let text = draft
        draft = ""
        send(text)
    }

    private func send(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            store.send(text)
        }
    }
}

// MARK: - Agent avatar

private struct AgentAvatar: View {
    let agent: ChatAgent
    var body: some View {
        ZStack {
            Circle().fill(agent.avatarBg)
            Text(agent.avatarInitial)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let alignment: HorizontalAlignment

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(message.text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isUser ? Theme.accentDeep : .white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                    ? AnyShapeStyle(Theme.accent)
                    : AnyShapeStyle(Theme.card),
                    in: bubbleShape
                )
                .overlay(
                    bubbleShape
                        .strokeBorder(
                            isUser ? Color.clear : Theme.cardOverlay,
                            lineWidth: 1
                        )
                )

            Text(timeLabel(message.timestamp))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    private var bubbleShape: some InsettableShape {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: isUser ? 16 : 4,
            bottomTrailingRadius: isUser ? 4 : 16,
            topTrailingRadius: 16,
            style: .continuous
        )
    }

    private func timeLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

// MARK: - System bubble

private struct SystemBubble: View {
    let text: String
    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.cardOverlay, in: .capsule)
                .overlay(Capsule().strokeBorder(Theme.cardOverlay, lineWidth: 1))
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.accent.opacity(phase == i ? 1.0 : 0.35))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.0 : 0.85)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.cardOverlay, lineWidth: 1)
        )
        .onAppear { animate() }
    }

    private func animate() {
        Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = (phase + 1) % 3
            }
        }
    }
}
