import AVKit
import PhotosUI
import SwiftUI

/// Private messages: the inbox list (embedded in the Paddock tab) with
/// conversations pushed on top, and a compose button to start one.
struct InboxView: View {
    @State var model: InboxViewModel
    let myName: String
    /// Recent room members, offered when starting a new conversation.
    var suggestions: [(id: String, name: String)] = []
    @Binding var path: [DMTarget]

    @State private var composing = false

    struct DMTarget: Hashable {
        let id: String
        let name: String
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                Theme.background.ignoresSafeArea()
                content

                // compose
                Button {
                    composing = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 54, height: 54)
                        .background(Theme.accentGradient, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                        .shadow(color: Theme.accent.opacity(0.55), radius: 14, y: 4)
                }
                .buttonStyle(.plain)
                .padding(20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DMTarget.self) { target in
                DMThreadView(model: ThreadViewModel(me: model.me, myName: myName, otherId: target.id, otherName: target.name))
                    .toolbar(.visible, for: .navigationBar)
            }
            .sheet(isPresented: $composing) {
                NewMessageSheet(suggestions: suggestions.filter { $0.id != model.me }) { target in
                    composing = false
                    path = [target]
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
            }
        }
        .task {
            InboxViewModel.enableNotifications()
            await model.load()
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
                Image(systemName: "paperplane")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.dimText)
                Text("NO PRIVATE MESSAGES YET")
                    .font(.f1(16).italic())
                    .foregroundStyle(.white)
                Text("Tap a name in the room, or the compose button, to start one. Conversations are end-to-end encrypted.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.dimText)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
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
            Avatar(name: thread.otherName, size: 40)

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

/// One private conversation — same toolkit as the room: text, photos,
/// videos and GIFs, all encrypted with the thread key.
struct DMThreadView: View {
    @State var model: ThreadViewModel
    @State private var draft = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var pendingMedia: StagedMedia?
    @State private var isLoadingMedia = false
    @State private var showGiphy = false
    @State private var decrypt: (@Sendable (Data) -> Data?)?
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty || pendingMedia != nil
    }

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
                .onTapGesture { focused = false }
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

            inputBar
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(model.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .task { decrypt = await model.decryptor() }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let media = pendingMedia {
                PendingMediaRow(media: media) {
                    pendingMedia = nil
                    pickedItem = nil
                }
            }

            HStack(spacing: 10) {
                if GiphyService.isAvailable {
                    Button {
                        showGiphy = true
                    } label: {
                        Text("GIF")
                            .font(.f1(12).italic())
                            .foregroundStyle(Theme.violet)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.violet.opacity(0.7), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showGiphy) {
                        GiphyPicker { item, kind in
                            showGiphy = false
                            Task { await model.send("", giphy: (url: item.url, type: kind == .stickers ? "gifsticker" : "gif")) }
                        }
                        .presentationDetents([.medium, .large])
                        .presentationBackground(Theme.background)
                    }
                }

                PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos])) {
                    if isLoadingMedia {
                        ProgressView().tint(Theme.accent).frame(width: 26)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 21))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .disabled(isLoadingMedia)

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
                    .contentShape(Rectangle())
                    .onTapGesture { focused = true }

                Button {
                    let text = draft
                    let media = pendingMedia.map { (url: $0.url, type: $0.type) }
                    draft = ""
                    pendingMedia = nil
                    pickedItem = nil
                    Task { await model.send(text, media: media) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend ? Theme.accent : Theme.dimText)
                }
                .buttonStyle(.plain)
                .disabled(!canSend || model.isSending)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            isLoadingMedia = true
            Task {
                do { pendingMedia = try await MediaStaging.stage(item) } catch { model.errorText = error.localizedDescription }
                isLoadingMedia = false
            }
        }
    }

    private func bubble(_ message: DirectMessage) -> some View {
        let mine = message.fromId == model.me
        return VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            if message.isGiphy, let url = URL(string: message.text) {
                AnimatedGIFView(url: url)
                    .frame(width: 200, height: 200)
                    .background(message.mediaType == "gif" ? Theme.card : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if let mediaType = message.mediaType {
                MediaBubble(id: message.id, type: mediaType, decrypt: decrypt)
            }
            if !message.text.isEmpty && !message.isGiphy {
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
            }
            Text(message.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .foregroundStyle(Theme.faintText)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}

/// Start a conversation: pick a recent paddock member or type an exact paddock name.
struct NewMessageSheet: View {
    let suggestions: [(id: String, name: String)]
    let onPick: (InboxView.DMTarget) -> Void

    @State private var name = ""
    @State private var notFound = false
    @State private var searching = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                TrioSlashes(height: 16)
                Text("NEW MESSAGE")
                    .font(.f1(20).italic())
                    .foregroundStyle(Theme.chromeText)
            }
            .padding(.top, 18)

            HStack(spacing: 8) {
                TextField("Paddock name", text: $name)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { Task { await find() } }
                    .padding(12)
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                Button {
                    Task { await find() }
                } label: {
                    if searching {
                        ProgressView().tint(Theme.onAccent).frame(width: 44)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 44)
                    }
                }
                .frame(height: 44)
                .background(name.trimmingCharacters(in: .whitespaces).count >= 3 ? Theme.accent : Color.gray.opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 10))
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).count < 3 || searching)
            }
            if notFound {
                Text("No one in the paddock goes by that name — it has to match exactly.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.live)
            }

            if !suggestions.isEmpty {
                Text("RECENTLY IN THE PADDOCK")
                    .font(.f1(11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.dimText)
                    .padding(.top, 6)
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(suggestions, id: \.id) { member in
                            Button {
                                onPick(InboxView.DMTarget(id: member.id, name: member.name))
                            } label: {
                                HStack {
                                    Text(member.name)
                                        .font(.f1(14).italic())
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "envelope")
                                        .foregroundStyle(Theme.accent)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Theme.card)
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.glassStroke, lineWidth: 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onAppear { focused = suggestions.isEmpty }
    }

    private func find() async {
        searching = true
        defer { searching = false }
        if let found = await ChatService.lookup(name: name) {
            notFound = false
            onPick(InboxView.DMTarget(id: found.id, name: found.name))
        } else {
            notFound = true
        }
    }
}
