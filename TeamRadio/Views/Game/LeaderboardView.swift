import SwiftUI

/// Paddock → Leaderboard. Figma: Prediction Game → Paddock — Leaderboard.
struct LeaderboardView: View {
    @State private var scope: LeaderboardService.Scope = .season
    @State private var board: LeaderboardService.Board?
    @State private var lastRound: Race?
    @State private var userId: String?
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showLeagues = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    scopeButton("SEASON", .season)
                    scopeButton(lastRound.map { "R\($0.round) \(PicksCard.shortName($0))" } ?? "LAST ROUND", .round)
                    Button { showLeagues = true } label: {
                        NeonChip(title: "LEAGUES", tint: Theme.violet, selected: showLeagues)
                    }
                    .buttonStyle(.plain)
                }
                if showLeagues {
                    LeaguesPanel(userId: userId, year: lastRound?.season ?? String(Calendar.current.component(.year, from: .now)))
                } else {
                    content
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: scope) { _, _ in Task { await load() } }
    }

    private func scopeButton(_ title: String, _ value: LeaderboardService.Scope) -> some View {
        Button { scope = value; showLeagues = false } label: {
            NeonChip(title: title, tint: Theme.accent, selected: scope == value && !showLeagues)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && board == nil {
            ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.top, 40)
        } else if let errorText {
            message(errorText)
        } else if let board, !board.top.isEmpty {
            Text("\(board.total.formatted()) PLAYERS · \(scope == .season ? "SEASON \(lastRound?.season ?? "")" : "ROUND \(lastRound?.round ?? "")")")
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.faintText)
            topThree(Array(board.top.prefix(3)))
            rows(Array(board.top.dropFirst(3)), strategist: board.strategist)
            if let me = board.me {
                LeaderRow(rank: "\(me.rank)", name: "\(me.name) (you)",
                          detail: "\(me.exact) exact", points: me.points, style: .me)
            }
        } else {
            message("No scores yet. The leaderboard fills up once the first race with picks has been scored.")
        }
    }

    private func topThree(_ top: [LeaderboardService.Entry]) -> some View {
        // Podium order: P2, P1, P3.
        let order = [1, 0, 2].compactMap { top.indices.contains($0) ? top[$0] : nil }
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(order) { entry in
                let first = entry.rank == 1
                VStack(spacing: 4) {
                    Text(String(entry.name.prefix(1)).uppercased())
                        .font(.f1(15))
                        .foregroundStyle(first ? Theme.onAccent : .white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(first ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.1))))
                    Text(entry.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(entry.points) PTS")
                        .font(.f1(15))
                        .foregroundStyle(first ? Theme.accent : .white)
                    Text("P\(entry.rank)")
                        .font(.f1(14))
                        .foregroundStyle(first ? Color(red: 1, green: 0.75, blue: 0.2) : Theme.dimText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(height: first ? 134 : 116, alignment: .bottom)
                .background(RoundedRectangle(cornerRadius: 16).fill(first ? Theme.accent.opacity(0.12) : Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(first ? Theme.accent : Color.white.opacity(0.08)))
                .shadow(color: first ? Theme.accent.opacity(0.4) : .clear, radius: 8)
            }
        }
    }

    private func rows(_ entries: [LeaderboardService.Entry], strategist: LeaderboardService.Strategist?) -> some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                LeaderRow(rank: "\(entry.rank)", name: entry.name, detail: "\(entry.exact) exact",
                          points: entry.points, style: entry.userId == userId ? .me : .normal)
            }
            // The AI Strategist sits beside the ranking as a benchmark.
            if let strategist {
                LeaderRow(rank: "AI", name: strategist.name, detail: "Benchmark · \(strategist.exact) exact",
                          points: strategist.points, style: .strategist)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08)))
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.dimText)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 40)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if userId == nil { userId = await ChatService.currentUserId() }
        if lastRound == nil, let season = try? await F1API.season() {
            lastRound = season.last { $0.isPast }
        }
        let year = lastRound?.season ?? String(Calendar.current.component(.year, from: .now))
        do {
            board = try await LeaderboardService.board(scope: scope, round: scope == .round ? lastRound?.id : nil,
                                                       year: year, user: userId)
            errorText = nil
        } catch {
            errorText = "The leaderboard isn't available right now. Pull down to try again."
        }
    }
}

/// Figma: Game/Leaderboard row.
private struct LeaderRow: View {
    enum Style { case normal, me, strategist }

    let rank: String
    let name: String
    let detail: String
    let points: Int
    let style: Style

    var body: some View {
        let tint: Color = style == .me ? Theme.accent : style == .strategist ? Theme.violet : .white
        HStack(spacing: 12) {
            Text(rank)
                .font(.f1(18))
                .foregroundStyle(tint)
                .frame(width: 34, alignment: .leading)
            Image(systemName: style == .strategist ? "cpu" : "person.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(style == .strategist ? Theme.violet : Theme.dimText)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dimText)
            }
            Spacer(minLength: 0)
            Text("\(points) PTS")
                .font(.f1(17))
                .foregroundStyle(style == .normal ? .white : tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(style == .normal ? Color.clear : tint.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style == .normal ? Color.clear : tint.opacity(0.7)))
        )
    }
}

/// Private leagues: create one and share the code, or join a friend's.
/// Standings are the members' season points.
private struct LeaguesPanel: View {
    let userId: String?
    let year: String

    @AppStorage("leagueCodes") private var codesText = ""
    @AppStorage("chatNickname") private var nickname = ""
    @State private var leagues: [LeaderboardService.League] = []
    @State private var newTitle = ""
    @State private var joinCode = ""
    @State private var busy = false
    @State private var errorText: String?

    private static let appStore = "https://apps.apple.com/app/id6804406860"
    private var codes: [String] { codesText.split(separator: ",").map(String.init) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if userId == nil || nickname.isEmpty {
                Text("Pick a Paddock name (Room tab) to create or join a league.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dimText)
            } else {
                ForEach(leagues) { league in leagueCard(league) }
                actions
            }
            if let errorText {
                Text(errorText).font(.system(size: 12)).foregroundStyle(Theme.live)
            }
        }
        .task(id: codesText) { await reload() }
    }

    private func leagueCard(_ league: LeaderboardService.League) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(league.title.uppercased()).font(.f1(17)).foregroundStyle(.white)
                    Text("CODE \(league.code)").font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.violet)
                }
                Spacer()
                ShareLink(item: URL(string: Self.appStore)!,
                          message: Text("Join my Team Radio league \"\(league.title)\" 🏁 Code: \(league.code)")) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.accent)
                }
                Menu {
                    Button("Leave league", role: .destructive) { Task { await leave(league.code) } }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.dimText)
                        .frame(width: 30, height: 30)
                }
            }
            ForEach(league.members ?? []) { m in
                HStack {
                    Text("\(m.rank)").font(.f1(15)).foregroundStyle(m.userId == userId ? Theme.accent : Theme.dimText)
                        .frame(width: 26, alignment: .leading)
                    Text(m.userId == userId ? "\(m.name) (you)" : m.name)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                    Text("\(m.points) PTS").font(.f1(15)).foregroundStyle(m.userId == userId ? Theme.accent : .white)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.violet.opacity(0.4)))
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(leagues.isEmpty ? "PLAY AGAINST YOUR FRIENDS" : "ANOTHER LEAGUE")
                .font(.f1(11, weight: .bold)).tracking(2).foregroundStyle(Theme.faintText)
            HStack(spacing: 8) {
                TextField("League name", text: $newTitle)
                    .textFieldStyle(.plain).padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                Button("CREATE") { Task { await create() } }
                    .font(.f1(13, weight: .bold)).foregroundStyle(Theme.accent)
                    .disabled(busy || newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            HStack(spacing: 8) {
                TextField("Code from a friend", text: $joinCode)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .textFieldStyle(.plain).padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                Button("JOIN") { Task { await join() } }
                    .font(.f1(13, weight: .bold)).foregroundStyle(Theme.accent)
                    .disabled(busy || joinCode.count < 6)
            }
        }
    }

    private func reload() async {
        var loaded: [LeaderboardService.League] = []
        for code in codes {
            if let l = await LeaderboardService.leagueStandings(code: code, year: year), l.error == nil { loaded.append(l) }
        }
        leagues = loaded
    }

    private func remember(_ code: String) {
        if !codes.contains(code) { codesText = (codes + [code]).joined(separator: ",") }
    }

    private func create() async {
        guard let userId else { return }
        busy = true; defer { busy = false }
        if let l = await LeaderboardService.league("create", user: userId, name: nickname, title: newTitle), l.error == nil {
            newTitle = ""; errorText = nil; remember(l.code)
        } else { errorText = "Couldn't create the league. Try again." }
    }

    private func join() async {
        guard let userId else { return }
        busy = true; defer { busy = false }
        let code = joinCode.uppercased().trimmingCharacters(in: .whitespaces)
        if let l = await LeaderboardService.league("join", user: userId, name: nickname, code: code) {
            if let error = l.error { errorText = error.prefix(1).uppercased() + error.dropFirst() + "." }
            else { joinCode = ""; errorText = nil; remember(l.code) }
        } else { errorText = "Couldn't join. Check your connection." }
    }

    private func leave(_ code: String) async {
        guard let userId else { return }
        _ = await LeaderboardService.league("leave", user: userId, name: nickname, code: code)
        codesText = codes.filter { $0 != code }.joined(separator: ",")
    }
}
