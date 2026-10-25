#if DEBUG
import CloudKit
import SwiftUI

// Emoji reactions on messages: three drafts of how a reaction shows on a
// bubble, each with the long-press picker open on one message.

enum ReactionDraftStyle { case corner, pill, chips }

/// The shipped components with sample data: `-DesignLab reactLive` shows the
/// room with chips, and `-DesignPage 1` also opens the long-press picker
/// (`2`: on my own message).
struct ReactionsLive: View {
    @State private var store = ReactionStore()
    @State private var pressed: PressedMessage?
    @State private var frames: [String: CGRect] = [:]
    private let messages: [ChatMessage] = [
        ("m1", "Did you see that pass into turn 1?? 🤯", "GridWalker", "u1"),
        ("m2", "Best start of the season easily", "Vasse", "me"),
        ("m3", "Bwoah. Leave him alone, he knows what he's doing.", "Kimi_Fan", "u3"),
        ("m4", "Tyres won't last 20 laps on that compound", "ApexHunter", "u4"),
    ].map { ChatMessage(id: CKRecord.ID(recordName: $0.0), text: $0.1, sender: $0.2, senderId: $0.3, date: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PADDOCK").font(.f1(28).italic()).foregroundStyle(.white).padding(.top, 8)
            ForEach(messages) { message in
                let mine = message.senderId == "me"
                VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                    ChatBubble(message: message, isMine: mine)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frames[message.id.recordName] = $0 }
                    ReactionChips(chips: store.chips(for: message.id.recordName)) { _ in }
                        .padding(.leading, mine ? 0 : 38)
                }
                .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
                .opacity(pressed?.id == message.id.recordName ? 0 : 1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .messageMenu($pressed, mine: { store.mine(on: $0) }) { _, _ in }
        .task {
            store.me = "me"
            let r = { (m: String, u: String, e: String) in Reaction(messageId: m, userId: u, emoji: e) }
            store.replace(with: [
                "m1": [r("m1", "a", "🔥"), r("m1", "b", "🔥"), r("m1", "c", "🔥"), r("m1", "me", "🔥"), r("m1", "d", "😮"), r("m1", "e", "😮")],
                "m2": [r("m2", "a", "💯"), r("m2", "b", "💯"), r("m2", "c", "💯")],
                "m3": [r("m3", "me", "😂"), r("m3", "a", "😂"), r("m3", "b", "😂"), r("m3", "c", "❤️"), r("m3", "d", "❤️"), r("m3", "e", "🏁")],
            ])
            let page = UserDefaults.standard.integer(forKey: "DesignPage")
            guard page > 0 else { return }
            try? await Task.sleep(for: .seconds(1.5))
            let message = messages[page == 2 ? 1 : 3]
            let mine = message.senderId == "me"
            presentWithoutSlide($pressed, PressedMessage(
                id: message.id.recordName, frame: frames[message.id.recordName] ?? .zero, isMine: mine, leading: mine ? 0 : 38,
                content: AnyView(ChatBubble(message: message, isMine: mine)),
                actions: mine ? [] : [
                    MessageAction(title: "Message \(message.sender) privately", systemImage: "envelope") {},
                    MessageAction(title: "Report message", systemImage: "exclamationmark.bubble", destructive: true) {},
                    MessageAction(title: "Block this user", systemImage: "hand.raised", destructive: true) {},
                ]))
        }
    }
}

struct ReactionsDraft: View {
    let style: ReactionDraftStyle
    var pressed = false

    private let title: String
    init(style: ReactionDraftStyle, pressed: Bool = false) {
        self.style = style
        self.pressed = pressed
        if pressed { title = "LONG PRESS (ALL VARIANTS)"; return }
        switch style {
        case .corner: title = "A · CORNER BADGE"
        case .pill: title = "B · PILL UNDER THE BUBBLE"
        case .chips: title = "C · CHIPS WITH COUNTS"
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                VStack(spacing: 18) {
                    DraftBubble(sender: "GridWalker", text: "Did you see that pass into turn 1?? 🤯", time: "14:02",
                                isMine: false, reactions: [("🔥", 4, true), ("😮", 2, false)], style: style)
                    DraftBubble(sender: "Vasse", text: "Best start of the season easily", time: "14:03",
                                isMine: true, reactions: [("💯", 3, false)], style: style)
                    DraftBubble(sender: "Kimi_Fan", text: "Bwoah. Leave him alone, he knows what he's doing.", time: "14:04",
                                isMine: false, reactions: [("😂", 6, true), ("❤️", 2, false), ("🏁", 1, false)], style: style)
                    // Long press on ApexHunter's message: the screen dims,
                    // the message lifts in place, the picker sits above it
                    // and the actions below.
                    if !pressed {
                        DraftBubble(sender: "ApexHunter", text: "Tyres won't last 20 laps on that compound", time: "14:05",
                                    isMine: false, reactions: [], style: style)
                    } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ReactionPicker(style: style)
                        DraftBubble(sender: "ApexHunter", text: "Tyres won't last 20 laps on that compound", time: "14:05",
                                    isMine: false, reactions: [], style: style)
                            .scaleEffect(1.03, anchor: .leading)
                        ActionMenu()
                            .padding(.leading, 38)
                    }
                    .padding(.top, 12)
                    .background(Color.black.opacity(0.6).frame(width: 3000, height: 4000))
                    .zIndex(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .zIndex(1)
            }

            VStack {
                Spacer()
                Text(title)
                    .font(.f1(12, weight: .bold)).tracking(2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.accent))
                    .padding(.bottom, 30)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RACE WEEKEND").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.live)
                Text("PADDOCK").font(.f1(28).italic()).foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

/// The six quick reactions plus "more", above the pressed message.
private struct ReactionPicker: View {
    let style: ReactionDraftStyle
    private let emojis = ["❤️", "😂", "🔥", "👍", "😮", "🏁"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(emojis.enumerated()), id: \.offset) { i, e in
                Text(e)
                    .font(.system(size: 28))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(i == 2 ? Color.white.opacity(0.14) : .clear))
                    .scaleEffect(i == 2 ? 1.18 : 1)
            }
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .padding(.leading, 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(white: 0.17))
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        )
        .padding(.leading, 30)
    }
}

/// The long-press actions the app already has, under the message.
private struct ActionMenu: View {
    private let rows: [(String, String, Bool)] = [
        ("Message ApexHunter privately", "envelope", false),
        ("Report message", "exclamationmark.bubble", true),
        ("Block ApexHunter", "hand.raised", true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack {
                    Text(row.0)
                    Spacer()
                    Image(systemName: row.1)
                }
                .font(.system(size: 16))
                .foregroundStyle(row.2 ? Theme.live : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                if i < rows.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
            }
        }
        .frame(width: 250)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.15)))
    }
}

/// A chat bubble as the app draws it, with reactions in the draft's style.
/// Reactions: (emoji, count, mine).
private struct DraftBubble: View {
    let sender: String
    let text: String
    let time: String
    let isMine: Bool
    let reactions: [(String, Int, Bool)]
    let style: ReactionDraftStyle

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isMine { Avatar(name: sender, size: 30) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(sender).font(.f1(12).italic()).foregroundStyle(isMine ? Theme.accent : .white.opacity(0.8))
                    Text(time).font(.system(size: 10)).foregroundStyle(Theme.faintText)
                }
                bubble
                if style == .chips, !reactions.isEmpty { chips }
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    private var bubble: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isMine ? Theme.accent.opacity(0.25) : Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isMine ? Theme.accent.opacity(0.4) : Theme.cardStroke, lineWidth: 1))
            )
            .overlay(alignment: isMine ? .topLeading : .topTrailing) {
                if style == .corner, !reactions.isEmpty { corner.offset(x: isMine ? -14 : 14, y: -24) }
            }
            .padding(.top, style == .corner && !reactions.isEmpty ? 8 : 0)
            .overlay(alignment: isMine ? .bottomLeading : .bottomTrailing) {
                if style == .pill, !reactions.isEmpty { pill.offset(x: isMine ? -6 : 6, y: 14) }
            }
            .padding(.bottom, style == .pill && !reactions.isEmpty ? 12 : 0)
    }

    // A: iMessage-style badges overlapping the top corner.
    private var corner: some View {
        HStack(spacing: -8) {
            ForEach(Array(reactions.prefix(3).enumerated()), id: \.offset) { _, r in
                Text(r.0)
                    .font(.system(size: 15))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(r.2 ? Theme.accent.opacity(0.9) : Color(white: 0.2)))
                    .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2.5))
            }
        }
    }

    // B: WhatsApp-style pill hanging off the bottom edge, with the total.
    private var pill: some View {
        HStack(spacing: 2) {
            ForEach(Array(reactions.prefix(3).enumerated()), id: \.offset) { _, r in
                Text(r.0).font(.system(size: 13))
            }
            Text("\(reactions.reduce(0) { $0 + $1.1 })")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.leading, 2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color(white: 0.2)))
        .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 2))
    }

    // C: one chip per emoji with its count; yours outlined in the accent.
    // Tapping a chip adds or removes your reaction.
    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(Array(reactions.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 4) {
                    Text(r.0).font(.system(size: 13))
                    Text("\(r.1)").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(r.2 ? Theme.accent : .white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(r.2 ? Theme.accent.opacity(0.15) : Theme.card))
                .overlay(Capsule().strokeBorder(r.2 ? Theme.accent.opacity(0.7) : Theme.cardStroke, lineWidth: 1))
            }
        }
        .padding(.top, 4)
    }
}
#endif
