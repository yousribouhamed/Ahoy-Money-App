import Foundation
import SwiftUI

// MARK: - Message model

/// A single message in the support chat.
///
/// We track sender role (user / agent / bot / system) plus quick-reply chips
/// the agent can attach to a message — exactly the pattern used by Revolut /
/// Monzo / Wise live chat.
struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date
    /// Quick replies attached to this (agent / bot) message — tap to send.
    let quickReplies: [String]

    enum Role: String, Hashable, Codable {
        case user
        case agent
        case bot
        case system
    }

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        timestamp: Date = Date(),
        quickReplies: [String] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.quickReplies = quickReplies
    }
}

// MARK: - Agent

/// The on-screen "agent" identity. Real apps round-robin to a human; for
/// the demo we have one named persona with an online status.
struct ChatAgent: Hashable {
    let displayName: String
    let role: String          // "Specialist", "Senior support"
    let avatarBg: Color
    let avatarInitial: String
    var isOnline: Bool
}

// MARK: - Store

/// Process-wide live chat store.
///
/// Messages mutate `@Observable` state so SwiftUI re-renders. The "agent"
/// reply is simulated locally with a typing pause + intent-matched canned
/// response, but the surface area mirrors what a real WebSocket would feed —
/// drop-in replaceable.
@Observable
final class ChatStore {
    var messages: [ChatMessage] = []
    var agent: ChatAgent
    var isAgentTyping: Bool = false
    /// Whether the chat has any unread reply since the user closed it.
    var hasUnread: Bool = false

    init() {
        self.agent = ChatAgent(
            displayName: "Mira",
            role: "Specialist",
            avatarBg: Color(red: 0.62, green: 0.40, blue: 1.00),
            avatarInitial: "M",
            isOnline: true
        )
        seedWelcome()
    }

    // MARK: Public API

    /// Called when the user taps Send.
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        scheduleAgentReply(to: trimmed)
    }

    /// Reset the conversation — used by "End chat" in the menu.
    func reset() {
        messages.removeAll()
        isAgentTyping = false
        hasUnread = false
        seedWelcome()
    }

    // MARK: Seed

    private func seedWelcome() {
        messages = [
            ChatMessage(
                role: .system,
                text: "You're now connected with \(agent.displayName) (\(agent.role))."
            ),
            ChatMessage(
                role: .agent,
                text: "Hi 👋 I'm \(agent.displayName) from Ahoy support. How can I help today?",
                quickReplies: [
                    "Card help",
                    "Transfer issue",
                    "Account & limits",
                    "Something else"
                ]
            )
        ]
    }

    // MARK: Reply engine

    private func scheduleAgentReply(to userText: String) {
        // Bot acknowledges fast, "specialist" follows up after a longer beat —
        // mirrors the two-stage "auto-ack then human" pattern Revolut & Monzo use.
        isAgentTyping = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self else { return }
            let reply = Self.makeReply(to: userText)
            self.messages.append(reply)
            self.isAgentTyping = false
            self.hasUnread = true
        }
    }

    /// Tiny intent matcher — keyword-based, deterministic. The full app would
    /// route to a real NLU service; this is enough to feel responsive.
    private static func makeReply(to text: String) -> ChatMessage {
        let q = text.lowercased()

        if q.contains("card") || q.contains("freeze") || q.contains("block") {
            return ChatMessage(
                role: .agent,
                text: "Got it — anything to do with cards I can help with right here. Are you looking to freeze, replace, or reveal the details of a card?",
                quickReplies: ["Freeze a card", "Replace a card", "Reveal CVV", "Card limits"]
            )
        }
        if q.contains("transfer") || q.contains("send") || q.contains("schedule") {
            return ChatMessage(
                role: .agent,
                text: "Happy to help with transfers. Quick question — is the transfer one-time or recurring? If it's stuck, share the recipient name and I'll dig in on my end.",
                quickReplies: ["One-time", "Recurring", "It's stuck", "Cancel a scheduled one"]
            )
        }
        if q.contains("limit") || q.contains("daily") || q.contains("monthly") {
            return ChatMessage(
                role: .agent,
                text: "Limits live in Settings → Transfer Limits. You can adjust the daily and monthly caps with a quick Face ID. Want me to walk you through it?",
                quickReplies: ["Walk me through it", "Increase the limit", "Why was I blocked?"]
            )
        }
        if q.contains("fee") || q.contains("charge") {
            return ChatMessage(
                role: .agent,
                text: "Wallet-to-wallet is free. UAE bank transfers are AED 2 flat. International depends on corridor — I'll send you a breakdown for your destination if you tell me the country.",
                quickReplies: ["UK", "India", "USA", "Saudi Arabia"]
            )
        }
        if q.contains("kyc") || q.contains("verify") || q.contains("verification") {
            return ChatMessage(
                role: .agent,
                text: "Verification usually takes under 5 minutes. If yours is taking longer, send me the timestamp of when you submitted and I'll escalate.",
                quickReplies: ["Resubmit my ID", "How long it takes", "Why was I rejected?"]
            )
        }
        if q.contains("lost") || q.contains("stolen") || q.contains("hack") || q.contains("fraud") {
            return ChatMessage(
                role: .agent,
                text: "I'm freezing your cards now as a precaution. You're safe — no one can charge them. Can you tell me when you last used the card so I can flag suspicious activity?",
                quickReplies: ["Within last hour", "Earlier today", "I'm not sure"]
            )
        }
        if q.contains("thanks") || q.contains("thank you") {
            return ChatMessage(
                role: .agent,
                text: "Anytime 🙂 I'll stay here in case anything else comes up. Have a great day!",
                quickReplies: []
            )
        }

        // Generic acknowledgement + escalation hint.
        return ChatMessage(
            role: .agent,
            text: "Thanks for reaching out — I'll have a look on my end. Could you share a bit more so I can pinpoint it faster?",
            quickReplies: ["Card issue", "Transfer issue", "Account issue", "Something else"]
        )
    }
}
