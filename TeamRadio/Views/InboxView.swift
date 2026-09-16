import SwiftUI

/// Private messages: the inbox and, inside it, each conversation.
struct InboxView: View {
    let myName: String
    /// Open straight into a conversation (from "Message privately" in the room).
    var openWith: (id: String, name: String)? = nil

    @State private var model = InboxViewModel()
    @State private var path: [DMTarget] = []
    @Environment(\.dismiss) private var dismiss

    struct DMTarget: Hashable {
        let id: String
        let name: String
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        TrioSlashes(height: 16)
                        Text("MESSAGES")
                            .font(.f1(20).italic())
                            .foregroundStyle(Theme.chromeText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.f1(14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .navigationDestination(for: DMTarget.self) { target in
                DMThreadView(model: ThreadViewModel(me: model.me, myName: myName, otherId: target.id, otherName: target.name))
            }
        }
        .preferredColorScheme(.dark)
        .task {
            InboxViewModel.enableNotifications()
            await model.load()
            if let openWith, path.isEmpty {
                path = [DMTarget(id: openWith.id, name: openWith.name)]
            }
        }
        .onChange(of: path) { _, new in
            if new.isEmpty { Task { await model.load() } }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView().tint(Theme.accent)
        } else if model.threads.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.dimText)
                Text("NO PRIVATE MESSAGES YET")
                    .font(.f1(16).italic())
                    .foregroundStyle(.white)
                Text("Long-press any message in the paddock and choose “Message privately”. Conversations are end-to-end encrypted.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.dimText)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.threads) { thread in
                        NavigationLink(value: DMTarget(id: thread.otherId, name: thread.otherName)) {
                            row(thread)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .refreshable { await model.load() }
        }
        if let error = model.errorText {
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(Theme.live)
                .padding()
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func row(_ thread: InboxViewModel.Thread) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.card)
                    .overlay(Circle().strokeBorder(Theme.glassStroke, lineWidth: 1))
                Text(String(thread.otherName.prefix(1)).uppercased())
                    .font(.f1(16).italic())
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(thread.otherName)
                    .font(.f1(14).italic())
                    .foregroundStyle(.white)
                Text((thread.last.fromId == model.me ? "You: " : "") + thread.last.text)
                    .font(.system(size: 13))
                    .foregroundStyle(thread.unread > 0 ? .white : Theme.dimText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(thread.last.date.formatted(.relative(presentation: .numeric)))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faintText)
                if thread.unread > 0 {
                    Text("\(thread.unread)")
                        .font(.f1(11, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.accent, in: Capsule())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.glassStroke, lineWidth: 1))
        )
    }
}

/// One private conversation.
struct DMThreadView: View {
    @State var model: ThreadViewModel
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        Text("🔒 End-to-end encrypted — only you and \(model.otherName) can read this.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.faintText)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                        ForEach(model.messages) { message in
                            bubble(message)
                                .id(message.id)
                                .contextMenu {
                                    if message.fromId != model.me {
                                        Button(role: .destructive) {
                                            model.report(message)
                                        } label: {
                                            Label("Report message", systemImage: "exclamationmark.bubble")
                                        }
                                        Button(role: .destructive) {
                                            ChatModeration.block(model.otherId)
                                            model.messages.removeAll()
                                        } label: {
                                            Label("Block \(model.otherName)", systemImage: "hand.raised")
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages) { old, new in
                    if let last = new.last, old.last?.id != last.id {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if let error = model.errorText {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.live.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                TextField("Message \(model.otherName)…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.glassStroke, lineWidth: 1))
                    )
                    .foregroundStyle(.white)
                Button {
                    let text = draft
                    draft = ""
                    Task { await model.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.dimText : Theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || model.isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(model.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func bubble(_ message: DirectMessage) -> some View {
        let mine = message.fromId == model.me
        return VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(message.readable ? .white : Theme.dimText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(mine ? Theme.accent.opacity(0.25) : Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(mine ? Theme.accent.opacity(0.4) : Theme.cardStroke, lineWidth: 1))
                )
            Text(message.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .foregroundStyle(Theme.faintText)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}
