import AVKit
import CloudKit
import PhotosUI
import SwiftUI

/// Paddock chat: one shared room per race weekend, on CloudKit.
struct ChatView: View {
    @State private var model = ChatViewModel()
    @State private var draft = ""
    @State private var nicknameDraft = ""
    @State private var editingName = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var showGiphy = false
    @State private var pendingMedia: PendingMedia?
    @State private var isLoadingMedia = false
    @State private var inbox = InboxViewModel()
    @State private var mode: Mode = .room
    @State private var dmPath: [InboxView.DMTarget] = []

    enum Mode { case room, messages }

    struct Member: Identifiable {
        let id: String
        let name: String
    }
    /// Tapping an avatar or name shows this person's card with a Message button.
    @State private var memberCard: Member?

    /// Jump into a private conversation from anywhere in the room.
    private func openThread(id: String, name: String) {
        memberCard = nil
        mode = .messages
        dmPath = [InboxView.DMTarget(id: id, name: name)]
    }
    @FocusState private var nicknameFocused: Bool
    @FocusState private var draftFocused: Bool

    struct PendingMedia {
        let url: URL
        let type: String        // "image" | "video"
        let preview: UIImage?
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.accent.opacity(0.14), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.live.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 460
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.violet.opacity(0.08), .clear],
                center: .leading, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()

            switch model.state {
            case .checking:
                LoadingView()
            case .needsICloud:
                needsICloud
            case .ready:
                if !model.agreedToRules {
                    rulesGate
                } else if model.nickname.isEmpty || editingName {
                    nicknamePrompt
                } else {
                    chatRoom
                }
            }
        }
        .task { await model.start() }
        .task { await inbox.load() }
        .onDisappear { model.stop() }
        .sheet(item: $memberCard) { member in
            MemberCard(member: member) {
                openThread(id: member.id, name: member.name)
            } onBlock: {
                ChatModeration.block(member.id)
                model.messages.removeAll { $0.senderId == member.id }
                memberCard = nil
            }
            .presentationDetents([.height(300)])
            .presentationBackground(Theme.background)
        }
    }

    // MARK: - Gates

    private var needsICloud: some View {
        VStack(spacing: 12) {
            Text("☁️")
                .font(.system(size: 40))
            Text("SIGN IN TO iCLOUD")
                .font(.f1(20).italic())
                .foregroundStyle(.white)
            Text("The paddock chat uses your iCloud account — no sign-up needed. Enable iCloud in Settings and come back.")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    private var rulesGate: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PADDOCK RULES")
                .font(.f1(24).italic())
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 8) {
                Label("Be respectful — rivalry yes, abuse no.", systemImage: "flag.checkered")
                Label("No hate speech, harassment, or spam. Zero tolerance.", systemImage: "hand.raised.fill")
                Label("Long-press any message to report or block.", systemImage: "exclamationmark.bubble")
                Label("Reported content is reviewed and removed within 24 hours.", systemImage: "clock")
            }
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.85))

            Button {
                model.agreeToRules()
            } label: {
                Text("I AGREE — LET ME IN")
                    .font(.f1(15).italic())
                    .tracking(1)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
        )
        .padding(20)
    }

    private var nicknamePrompt: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PICK A PADDOCK NAME")
                .font(.f1(22).italic())
                .foregroundStyle(.white)
            Text("This is how other fans see you. Names are unique — first come, first served.")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
            TextField("e.g. GravelTrapHero", text: $nicknameDraft)
                .textFieldStyle(.plain)
                .focused($nicknameFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .onTapGesture { nicknameFocused = true }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        nicknameFocused = true
                    }
                }
            if let error = model.nicknameError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.live)
            }

            Button {
                Task {
                    if await model.claimNickname(nicknameDraft) {
                        editingName = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if model.isClaimingName {
                        ProgressView().tint(Theme.onAccent)
                    }
                    Text(editingName ? "REGISTER NAME" : "JOIN THE PADDOCK")
                        .font(.f1(15).italic())
                        .tracking(1)
                }
                .foregroundStyle(
                    nicknameDraft.trimmingCharacters(in: .whitespaces).count >= 3 ? Theme.onAccent : Theme.dimText
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    nicknameDraft.trimmingCharacters(in: .whitespaces).count >= 3 ? Theme.accent : Color.gray.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)
            .disabled(nicknameDraft.trimmingCharacters(in: .whitespaces).count < 3 || model.isClaimingName)

            if editingName {
                Button {
                    editingName = false
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.glassStroke, lineWidth: 1))
        )
        .padding(20)
    }

    // MARK: - Chat room

    private var chatRoom: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 9) {
                        TrioSlashes(height: 24)
                        Text("PADDOCK CHAT")
                    }
                        .font(.f1(30).italic())
                        .foregroundStyle(Theme.chromeText)
                    Text(model.roundTitle.uppercased())
                        .font(.f1(12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.dimText)
                }

                Spacer()

                // Current paddock name; tap to change it.
                Button {
                    nicknameDraft = model.nickname
                    editingName = true
                } label: {
                    HStack(spacing: 5) {
                        Text(model.nickname)
                            .font(.f1(13).italic())
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.dimText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                            .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)

            // Room / Messages, the way every social app does it
            HStack(spacing: 8) {
                Button { mode = .room } label: {
                    NeonChip(title: "ROOM", tint: Theme.accent, selected: mode == .room)
                }
                .buttonStyle(.plain)
                Button { mode = .messages } label: {
                    NeonChip(title: inbox.totalUnread > 0 ? "MESSAGES · \(inbox.totalUnread)" : "MESSAGES",
                             tint: Theme.violet, selected: mode == .messages)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if mode == .messages {
                InboxView(model: inbox, myName: model.nickname, suggestions: recentMembers, path: $dmPath)
            } else {
                roomBody
            }
        }
    }

    private var roomBody: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if model.canLoadOlder {
                            Button {
                                Task { await model.loadOlder() }
                            } label: {
                                HStack(spacing: 6) {
                                    if model.isLoadingOlder {
                                        ProgressView().tint(Theme.dimText)
                                    }
                                    Text("LOAD EARLIER MESSAGES")
                                        .font(.f1(11, weight: .bold))
                                        .tracking(1)
                                }
                                .foregroundStyle(Theme.dimText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isLoadingOlder)
                        }
                        if model.messages.isEmpty {
                            Text("Nothing here yet — be the first voice in the paddock. 🏁")
                                .font(.subheadline)
                                .foregroundStyle(Theme.dimText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        ForEach(model.messages) { message in
                            ChatBubble(message: message, isMine: model.isMine(message)) {
                                memberCard = Member(id: message.senderId, name: message.sender)
                            }
                                .id(message.id)
                                // New arrivals spring in from the bottom edge.
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .contextMenu {
                                    if !model.isMine(message) {
                                        Button {
                                            openThread(id: message.senderId, name: message.sender)
                                        } label: {
                                            Label("Message \(message.sender) privately", systemImage: "envelope")
                                        }
                                        Button(role: .destructive) {
                                            model.report(message)
                                        } label: {
                                            Label("Report message", systemImage: "exclamationmark.bubble")
                                        }
                                        Button(role: .destructive) {
                                            model.block(message)
                                        } label: {
                                            Label("Block this user", systemImage: "hand.raised")
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.messages)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { draftFocused = false }
                .onChange(of: model.messages) { old, new in
                    // Follow the conversation only when something NEW arrives
                    // at the bottom — paging in older history must not yank
                    // the scroll position down.
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
    }

    /// People who posted in the room recently, newest first, for starting a private message.
    private var recentMembers: [(id: String, name: String)] {
        var seen: Set<String> = []
        return model.messages.reversed().compactMap { m in
            guard !model.isMine(m), !seen.contains(m.senderId) else { return nil }
            seen.insert(m.senderId)
            return (m.senderId, m.sender)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty || pendingMedia != nil
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let media = pendingMedia {
                HStack(spacing: 10) {
                    if let preview = media.preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: media.type == "video" ? "video.fill" : "photo.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 52, height: 52)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    }
                    Text(media.type == "video" ? "Video attached" : "Photo attached")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.dimText)
                    Spacer()
                    Button {
                        pendingMedia = nil
                        pickedItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.dimText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
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
                            let type = kind == .stickers ? "gifsticker" : "gif"
                            Task { await model.send("", giphy: (url: item.url, type: type)) }
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

                TextField("Say something…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($draftFocused)
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
                    .onTapGesture { draftFocused = true }

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
                await loadPicked(item)
                isLoadingMedia = false
            }
        }
    }

    /// Compresses the picked photo (max 1440 px JPEG) or accepts a video up
    /// to 25 MB, staging it as a temp file ready to upload.
    private func loadPicked(_ item: PhotosPickerItem) async {
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .audiovisualContent) }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            model.errorText = "Couldn't load that from your library."
            return
        }
        let temp = FileManager.default.temporaryDirectory
        if isVideo {
            guard data.count <= 25 * 1024 * 1024 else {
                model.errorText = "Videos up to 25 MB only — try a shorter clip."
                return
            }
            let url = temp.appendingPathComponent("upload-\(UUID().uuidString).mov")
            guard (try? data.write(to: url)) != nil else { return }
            let thumb = await videoThumbnail(url: url)
            pendingMedia = PendingMedia(url: url, type: "video", preview: thumb)
        } else {
            guard let image = UIImage(data: data) else {
                model.errorText = "That image couldn't be read."
                return
            }
            let scaled = image.scaledDown(maxDimension: 1440)
            guard let jpeg = scaled.jpegData(compressionQuality: 0.75) else { return }
            let url = temp.appendingPathComponent("upload-\(UUID().uuidString).jpg")
            guard (try? jpeg.write(to: url)) != nil else { return }
            pendingMedia = PendingMedia(url: url, type: "image", preview: scaled)
        }
    }

    private func videoThumbnail(url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: .zero) { cg, _, _ in
                continuation.resume(returning: cg.map(UIImage.init))
            }
        }
    }
}

private extension UIImage {
    func scaledDown(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let isMine: Bool
    /// Tapping someone's name opens a private thread with them.
    var onSender: (() -> Void)? = nil
    @State private var gifAspect: CGFloat = 1

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isMine {
                Avatar(name: message.sender, size: 30)
                    .onTapGesture { onSender?() }
            }
            bubbleColumn
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    private var bubbleColumn: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(message.sender)
                    .font(.f1(12).italic())
                    .foregroundStyle(isMine ? Theme.accent : .white.opacity(0.8))
                    .contentShape(Rectangle())
                    .onTapGesture { if !isMine { onSender?() } }
                Text(message.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faintText)
            }
            if message.isGiphy, let url = URL(string: message.text) {
                AnimatedGIFView(url: url) { size in
                    if size.width > 0, size.height > 0 { gifAspect = size.width / size.height }
                }
                .frame(width: 200, height: min(max(200 / gifAspect, 80), 280))
                    .background(message.mediaType == "gif" ? Theme.card : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if let mediaType = message.mediaType {
                MediaBubble(id: message.id, type: mediaType)
            }

            if !message.text.isEmpty && !message.isGiphy {
                Text(ChatModeration.cleaned(message.text))
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isMine ? Theme.accent.opacity(0.25) : Theme.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(isMine ? Theme.accent.opacity(0.4) : Theme.cardStroke, lineWidth: 1)
                            )
                    )
            }
        }
    }
}

/// Initial-letter avatar, tinted from the name so each person keeps a colour.
struct Avatar: View {
    let name: String
    var size: CGFloat = 30

    private var tint: Color {
        let palette = [Theme.accent, Theme.violet, Theme.live, Color(red: 0.2, green: 0.9, blue: 0.6), Color(red: 1.0, green: 0.75, blue: 0.2)]
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return palette[hash % palette.count]
    }

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.18))
            Circle().strokeBorder(tint.opacity(0.6), lineWidth: 1)
            Text(String(name.prefix(1)).uppercased())
                .font(.f1(size * 0.45).italic())
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

/// The card you get when tapping someone: who they are and one clear action.
struct MemberCard: View {
    let member: ChatView.Member
    let onMessage: () -> Void
    let onBlock: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Avatar(name: member.name, size: 72)
                .padding(.top, 22)
            Text(member.name)
                .font(.f1(22).italic())
                .foregroundStyle(Theme.chromeText)
            Text("PADDOCK MEMBER")
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.dimText)

            Button(action: onMessage) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text("MESSAGE \(member.name.uppercased())")
                }
                .font(.f1(15).italic())
                .tracking(1)
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: Theme.accent.opacity(0.45), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 6)

            Button(role: .destructive, action: onBlock) {
                Text("Block")
                    .font(.subheadline)
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A photo or video inside a chat bubble: downloads lazily, photos open
/// full screen, videos play in place.
struct MediaBubble: View {
    let id: CKRecord.ID
    let type: String

    @State private var fileURL: URL?
    @State private var showFullImage = false

    var body: some View {
        Group {
            if let fileURL {
                if type == "video" {
                    VideoPlayer(player: AVPlayer(url: fileURL))
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else if let image = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .onTapGesture { showFullImage = true }
                        .fullScreenCover(isPresented: $showFullImage) {
                            ZStack(alignment: .topTrailing) {
                                Color.black.ignoresSafeArea()
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                Button {
                                    showFullImage = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .padding(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                }
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.card)
                    .frame(width: 220, height: 140)
                    .overlay(ProgressView().tint(Theme.accent))
            }
        }
        .task(id: id.recordName) {
            fileURL = await ChatMediaCache.shared.url(for: id, type: type)
        }
    }
}


