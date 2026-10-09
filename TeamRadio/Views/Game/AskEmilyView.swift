import SwiftUI

/// "Ask the race engineer": fans ask Emily, she answers as a team-radio
/// message. Text only for now. Spec: Docs/ai-features.md.
struct AskEmilyView: View {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let fromEmily: Bool
        let text: String
    }

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Message] = [
        Message(fromEmily: true, text: "Radio check. Ask me anything about this weekend: sessions, results, strategy, the championship."),
    ]
    @State private var draft = ""
    @State private var waiting = false
    @FocusState private var focused: Bool

    private let suggestions = [
        "Who leads the championship?",
        "When is qualifying?",
        "What's an undercut?",
        "Who won the last race?",
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            bubble(message).id(message.id)
                        }
                        if waiting {
                            RadioTyping().id("typing")
                        }
                        if messages.count == 1 {
                            suggestionChips
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages) { _, _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
                .onChange(of: waiting) { _, on in
                    if on { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }
            inputBar
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("EmilyAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 2))
                .shadow(color: Theme.accent.opacity(0.5), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("EMILY")
                    .font(.f1(20))
                    .foregroundStyle(.white)
                Text("RACE ENGINEER · AI")
                    .font(.f1(11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.dimText)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func bubble(_ message: Message) -> some View {
        if message.fromEmily {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("TEAM RADIO")
                        .font(.f1(10, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundStyle(Theme.accent)
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(14)
            .frame(maxWidth: 320, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.accent.opacity(0.35)))
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accentGradient))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions, id: \.self) { q in
                Button { send(q) } label: {
                    Text(q)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().strokeBorder(Theme.accent.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                TextField("Ask Emily…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { send(draft) }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.1)))
                Button { send(draft) } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Theme.accent : Theme.faintText)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            Text("AI answers can be wrong. Unofficial fan app.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faintText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var canSend: Bool {
        !waiting && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !waiting else { return }
        draft = ""
        messages.append(Message(fromEmily: false, text: question))
        waiting = true
        Task {
            let user = await ChatService.currentUserId() ?? "anon-\(UIDevice.current.identifierForVendor?.uuidString ?? "x")"
            let answer = (try? await AskService.ask(question, user: user))
                ?? "Radio's breaking up. Ask me again in a minute."
            waiting = false
            messages.append(Message(fromEmily: true, text: answer))
        }
    }
}

/// Emily "keying the mic": a small live waveform while the answer loads.
private struct RadioTyping: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<14, id: \.self) { i in
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: 3, height: 6 + 16 * abs(sin(t * 7 + Double(i) * 0.6)))
                }
            }
            .frame(height: 24)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent.opacity(0.10)))
        }
    }
}

/// Countdown-tab entry: Emily's face and one line, opens the chat.
struct AskEmilyCard: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image("EmilyAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 2))
                    .shadow(color: Theme.accent.opacity(0.5), radius: 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ASK THE RACE ENGINEER")
                        .font(.f1(15).italic())
                        .foregroundStyle(.white)
                    Text("Emily answers on the radio: strategy, results, rules. AI.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.dimText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask Emily, the AI race engineer")
    }
}
