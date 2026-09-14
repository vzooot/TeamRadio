import SwiftUI

/// Live tick-by-tick countdown with a selectable target: tap any session chip
/// to count down to it. Defaults to the next session that hasn't started.
struct CountdownView: View {
    let race: Race

    @State private var selectedId: String?
    @State private var pinned = false

    private var sessions: [WeekendSession] { race.sessions }

    private func resolvedSelection(now: Date) -> WeekendSession? {
        if let selectedId, let chosen = sessions.first(where: { $0.id == selectedId }) {
            return chosen
        }
        // Default to whatever is on track right now, then the next session.
        if let live = sessions.first(where: {
            $0.date <= now && now < $0.date.addingTimeInterval($0.kind.expectedDuration)
        }) {
            return live
        }
        return sessions.first(where: { $0.date > now }) ?? sessions.last
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let session = resolvedSelection(now: now)
            let target = session?.date ?? now
            let remaining = target.timeIntervalSince(now)

            VStack(spacing: 14) {
                sessionPicker(now: now, selected: session)

                if let session {
                    Text("\(session.kind.rawValue.uppercased()) · \(session.date.formatted(.dateTime.weekday(.wide).hour().minute()).uppercased())")
                        .font(.f1(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.dimText)
                }

                // TEMP screenshot hooks: `-DemoLights 3` pretends race week is here,
                // `-DemoLive YES` pretends the session has started.
                let demoLights = UserDefaults.standard.integer(forKey: "DemoLights")
                let demoLive = UserDefaults.standard.bool(forKey: "DemoLive")

                if remaining > 0 && !demoLive {
                    let realLit = StartLightsView.litCount(secondsRemaining: remaining)
                    // TEMP preview: two lamps always on so lit vs. armed can be compared — revert later.
                    let lit = demoLights > 0 ? demoLights : max(2, realLit)
                    DotMatrixBoard(litLights: lit, pages: infoPages(session: session, remaining: remaining))
                    if demoLights > 0 || realLit > 0 {
                        Text(lit >= 5 ? "FINAL 24 HOURS" : "IT'S RACE WEEK")
                            .font(.f1(11, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(Theme.live)
                            .shadow(color: Theme.live.opacity(0.7), radius: 6)
                    }
                    let parts = split(remaining)
                    HStack(spacing: 10) {
                        NeonTile(value: parts.days, label: "DAYS")
                        NeonTile(value: parts.hours, label: "HRS")
                        NeonTile(value: parts.minutes, label: "MIN")
                        NeonTile(value: parts.seconds, label: "SEC", hot: true)
                    }
                    .padding(.top, 4)
                    .overlay(alignment: .bottom) {
                        // chassis screws between the tiles
                        GeometryReader { geo in
                            ForEach([0.25, 0.75], id: \.self) { f in
                                Screw(size: 9)
                                    .position(x: geo.size.width * f, y: geo.size.height + 8)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                } else if let session, demoLive || now < session.date.addingTimeInterval(session.kind.expectedDuration) {
                    // Lights out: the gantry goes dark the moment the session starts.
                    DotMatrixBoard(litLights: 0)
                    liveBanner(session)
                } else {
                    Text("🏁 \(session?.kind.rawValue.uppercased() ?? "SESSION") COMPLETE")
                        .font(.f1(20).italic())
                        .foregroundStyle(Theme.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }

                if let session, session.date.addingTimeInterval(session.kind.expectedDuration) > now {
                    pinButton(session: session)
                }
            }
            .onAppear { pinned = LiveActivityManager.hasPinIntent }
            .padding(18)
            .background(
                CarbonFiber()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Theme.glassStroke, lineWidth: 1)
                    )
                    .trioGlow(cornerRadius: 20)
            )
        }
    }

    /// Starts/stops the Wolt-style Live Activity on the Lock Screen and in
    /// the Dynamic Island.
    private func pinButton(session: WeekendSession) -> some View {
        Button {
            if pinned {
                LiveActivityManager.unpin()
                pinned = false
            } else {
                LiveActivityManager.start(race: race, session: session)
                pinned = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: pinned ? "pin.slash.fill" : "pin.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(pinned ? "UNPIN FROM LOCK SCREEN" : "PIN \(session.kind.short) TO LOCK SCREEN")
                    .font(.f1(12, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(pinned ? Theme.dimText : Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(pinned ? Theme.cardStroke : Theme.accent.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sessionPicker(now: Date, selected: WeekendSession?) -> some View {
        HStack(spacing: 6) {
            ForEach(sessions) { session in
                let isSelected = session.id == selected?.id
                Button {
                    selectedId = session.id
                } label: {
                    NeonChip(title: session.kind.short, tint: Self.tint(for: session.kind), selected: isSelected)
                        .opacity(session.date <= now && !isSelected ? 0.45 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// What the matrix screen shows when tapped, one page per tap.
    private func infoPages(session: WeekendSession?, remaining: TimeInterval) -> [String] {
        guard let session else { return [] }
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        return [
            session.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()),
            session.date.formatted(.dateTime.weekday(.abbreviated).day()).uppercased(),
            days > 0 ? "\(days) DAYS" : "\(hours) HRS",
            "RND \(race.round)",
        ]
    }

    /// Sector colours, like the 3D circuit: practice cyan, qualifying violet, race red.
    private static func tint(for kind: WeekendSession.Kind) -> Color {
        switch kind {
        case .practice1, .practice2, .practice3: Theme.accent
        case .sprintQualifying, .qualifying: Theme.violet
        case .sprint, .race: Theme.live
        }
    }

    // The elapsed session clock lives in the LiveSessionBanner at the top of
    // the screen — deliberately not repeated here.
    private func liveBanner(_ session: WeekendSession) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.live)
                .frame(width: 10, height: 10)
                .shadow(color: Theme.live, radius: 6)
            Text("\(session.kind.rawValue.uppercased()) IS LIVE")
                .font(.f1(22).italic())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func tile(_ value: Int, _ label: String, hot: Bool = false, tint: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.f1Digits(42))
                .foregroundStyle(hot ? AnyShapeStyle(Theme.liveGradient) : AnyShapeStyle(.white))
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy(duration: 0.3), value: value)
            Text(label)
                .font(.f1(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(hot ? Theme.live.opacity(0.55) : (tint?.opacity(0.35) ?? Theme.cardStroke), lineWidth: 1)
                )
        )
    }

    private func split(_ interval: TimeInterval) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let total = Int(interval)
        return (total / 86400, (total % 86400) / 3600, (total % 3600) / 60, total % 60)
    }
}

/// F1-broadcast style session clock: elapsed time since green light,
/// ticking with milliseconds at display refresh rate.
struct SessionClock: View {
    let start: Date

    var body: some View {
        TimelineView(.animation) { context in
            Text(Self.format(max(0, context.date.timeIntervalSince(start))))
                .contentTransition(.identity)
        }
    }

    static func format(_ elapsed: TimeInterval) -> String {
        let totalMs = Int(elapsed * 1000)
        let hours = totalMs / 3_600_000
        let minutes = (totalMs % 3_600_000) / 60_000
        let seconds = (totalMs % 60_000) / 1000
        let millis = totalMs % 1000
        return String(format: "%d:%02d:%02d.%03d", hours, minutes, seconds, millis)
    }
}

/// The five-light start gantry. Lights come on as race week progresses:
/// all five burn during the final 24 hours before lights out.
struct StartLightsView: View {
    let secondsRemaining: TimeInterval

    private var litCount: Int { Self.litCount(secondsRemaining: secondsRemaining) }

    static func litCount(secondsRemaining: TimeInterval) -> Int {
        let days = secondsRemaining / 86400
        if secondsRemaining <= 0 { return 0 }        // lights out — away we go
        if days >= 6 { return 0 }
        return min(5, Int((6 - days) / 6 * 5) + 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                ForEach(0..<5, id: \.self) { index in
                    lightColumn(on: index < litCount)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )

            if secondsRemaining > 0 && secondsRemaining < 6 * 86400 {
                Text(secondsRemaining < 86400 ? "FINAL 24 HOURS" : "IT'S RACE WEEK")
                    .font(.f1(11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Theme.live)
            }
        }
    }

    private func lightColumn(on: Bool) -> some View {
        VStack(spacing: 5) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(on ? Theme.live : Color.white.opacity(0.07))
                    .frame(width: 16, height: 16)
                    .shadow(color: on ? Theme.live.opacity(0.8) : .clear, radius: 6)
            }
        }
    }
}
