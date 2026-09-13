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
    @State private var pendingMedia: PendingMedia?
    @State private var isLoadingMedia = false
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
        .onDisappear { model.stop() }
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
                    Text("PADDOCK CHAT")
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
                            ChatBubble(message: message, isMine: model.isMine(message))
                                .id(message.id)
                                // New arrivals spring in from the bottom edge.
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .contextMenu {
                                    if !model.isMine(message) {
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

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(message.sender)
                    .font(.f1(12).italic())
                    .foregroundStyle(isMine ? Theme.accent : .white.opacity(0.8))
                Text(message.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faintText)
            }
            if let mediaType = message.mediaType {
                MediaBubble(id: message.id, type: mediaType)
            }

            if !message.text.isEmpty {
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
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
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
