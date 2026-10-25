import SwiftUI
import UIKit

/// The chips under a message: one per emoji with its count, mine outlined
/// in the accent. Tapping one adds or removes my reaction.
struct ReactionChips: View {
    let chips: [ReactionChip]
    let onTap: (String) -> Void

    var body: some View {
        if !chips.isEmpty {
            HStack(spacing: 6) {
                ForEach(chips.prefix(6)) { chip in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        onTap(chip.emoji)
                    } label: {
                        HStack(spacing: 4) {
                            Text(chip.emoji).font(.system(size: 13))
                            Text("\(chip.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(chip.mine ? Theme.accent : .white.opacity(0.7))
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(chip.mine ? Theme.accent.opacity(0.15) : Theme.card))
                        .overlay(Capsule().strokeBorder(chip.mine ? Theme.accent.opacity(0.7) : Theme.cardStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(chip.emoji) \(chip.count)\(chip.mine ? ", yours" : "")")
                }
            }
            .padding(.top, 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: chips)
        }
    }
}

/// A long-pressed message: where it sits on screen, a copy to lift, and
/// the actions offered under it.
struct PressedMessage: Identifiable {
    let id: String
    let frame: CGRect
    let isMine: Bool
    /// Indent of the bubble inside the row (the avatar in the room).
    var leading: CGFloat = 0
    let content: AnyView
    var actions: [MessageAction] = []
}

struct MessageAction: Identifiable {
    let title: String
    let systemImage: String
    var destructive = false
    let run: () -> Void
    var id: String { title }
}

extension View {
    /// Long press opens the reaction picker; hands over where the view is.
    func onLongPressToReact(_ action: @escaping (CGRect) -> Void) -> some View {
        modifier(LongPressToReact(action: action))
    }

    /// Shows the long-press picker over everything (tab bar included).
    func messageMenu(_ pressed: Binding<PressedMessage?>, mine: @escaping (String) -> String?,
                     react: @escaping (String, String) -> Void) -> some View {
        fullScreenCover(item: pressed) { message in
            MessageMenuOverlay(message: message, current: mine(message.id),
                               react: { react($0, message.id) },
                               dismiss: { dismissWithoutSlide(pressed) })
                .presentationBackground(.clear)
        }
    }
}

/// The cover appears and leaves without the system slide; the overlay
/// animates itself.
func presentWithoutSlide(_ binding: Binding<PressedMessage?>, _ value: PressedMessage) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { binding.wrappedValue = value }
}

private func dismissWithoutSlide(_ binding: Binding<PressedMessage?>) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { binding.wrappedValue = nil }
}

private final class FrameBox { var rect: CGRect = .zero }

private struct LongPressToReact: ViewModifier {
    let action: (CGRect) -> Void
    // A plain box, not observed: scrolling updates it without redrawing.
    @State private var frame = FrameBox()

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame.rect = $0 }
            .onLongPressGesture(minimumDuration: 0.3) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action(frame.rect)
            }
    }
}

/// Industry-standard long press: the screen dims, the message lifts in
/// place, the emoji row sits above it and the actions below.
private struct MessageMenuOverlay: View {
    let message: PressedMessage
    let current: String?
    let react: (String) -> Void
    let dismiss: () -> Void

    @State private var shown = false
    @State private var typing = false

    private let pickerHeight: CGFloat = 54
    private let rowHeight: CGFloat = 46
    private let gap: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let frame = message.frame.offsetBy(dx: -origin.x, dy: -origin.y)
            let menuHeight = typing || message.actions.isEmpty ? 0 : CGFloat(message.actions.count) * rowHeight + gap
            let total = pickerHeight + gap + frame.height + menuHeight
            let top = min(max(frame.minY - pickerHeight - gap, 8), max(geo.size.height - total - 8, 8))

            ZStack(alignment: .topLeading) {
                Color.black.opacity(shown ? 0.6 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                VStack(alignment: message.isMine ? .trailing : .leading, spacing: gap) {
                    picker
                        .padding(message.isMine ? .trailing : .leading, message.leading)
                        .scaleEffect(shown ? 1 : 0.4, anchor: message.isMine ? .bottomTrailing : .bottomLeading)
                        .opacity(shown ? 1 : 0)
                    message.content
                        .frame(width: frame.width, height: frame.height)
                        .scaleEffect(shown ? 1.03 : 1, anchor: message.isMine ? .trailing : .leading)
                        .allowsHitTesting(false)
                    if !typing && !message.actions.isEmpty {
                        actions
                            .padding(message.isMine ? .trailing : .leading, message.leading)
                            .scaleEffect(shown ? 1 : 0.6, anchor: message.isMine ? .topTrailing : .topLeading)
                            .opacity(shown ? 1 : 0)
                    }
                }
                .frame(width: frame.width, alignment: message.isMine ? .trailing : .leading)
                .offset(x: frame.minX, y: shown ? top : frame.minY - pickerHeight - gap)

                if typing {
                    EmojiInput { emoji in pick(emoji) }
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                }
            }
        }
        .onAppear { withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { shown = true } }
    }

    private var picker: some View {
        HStack(spacing: 4) {
            ForEach(ReactionService.quick, id: \.self) { emoji in
                Button { pick(emoji) } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(emoji == current ? Color.white.opacity(0.16) : .clear))
                        .scaleEffect(emoji == current ? 1.12 : 1)
                }
                .buttonStyle(.plain)
            }
            Button {
                withAnimation(.easeOut(duration: 0.2)) { typing = true }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(typing ? 0.25 : 0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More emoji")
            .padding(.leading, 2)
        }
        .padding(.horizontal, 8)
        .frame(height: pickerHeight)
        .background(
            Capsule().fill(Color(white: 0.17))
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        )
    }

    private var actions: some View {
        VStack(spacing: 0) {
            ForEach(Array(message.actions.enumerated()), id: \.element.id) { i, action in
                Button {
                    close(then: action.run)
                } label: {
                    HStack {
                        Text(action.title).lineLimit(1)
                        Spacer()
                        Image(systemName: action.systemImage)
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(action.destructive ? Theme.live : .white)
                    .padding(.horizontal, 16)
                    .frame(height: rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < message.actions.count - 1 { Divider().overlay(Color.white.opacity(0.08)) }
            }
        }
        .frame(width: min(message.frame.width - message.leading, 320))
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.15)))
    }

    private func pick(_ emoji: String) {
        UISelectionFeedbackGenerator().selectionChanged()
        react(emoji)
        close()
    }

    private func close(then after: (() -> Void)? = nil) {
        withAnimation(.easeOut(duration: 0.16)) { shown = false; typing = false }
        Task {
            try? await Task.sleep(for: .milliseconds(170))
            dismiss()
            after?()
        }
    }
}

/// An invisible field that opens the emoji keyboard and hands back the
/// first emoji typed: "+" in the picker, for any emoji.
private struct EmojiInput: UIViewRepresentable {
    let onPick: (String) -> Void

    final class Field: UITextField {
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
        }
    }

    func makeUIView(context: Context) -> Field {
        let field = Field()
        field.delegate = context.coordinator
        field.tintColor = .clear
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ uiView: Field, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let onPick: (String) -> Void
        init(onPick: @escaping (String) -> Void) { self.onPick = onPick }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let character = string.first, character.isEmoji {
                textField.resignFirstResponder()
                onPick(String(character))
            }
            return false
        }
    }
}

private extension Character {
    var isEmoji: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation || (first.properties.isEmoji && unicodeScalars.count > 1)
    }
}
