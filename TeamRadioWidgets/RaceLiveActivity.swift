import ActivityKit
import WidgetKit
import SwiftUI

/// Wolt-style live tracking: the pinned session countdown on the Lock Screen
/// and in the Dynamic Island, flipping to LIVE at lights out.
struct RaceLiveActivity: Widget {
    private let accent = Color(red: 0.18, green: 0.70, blue: 1.0)  // #2EB2FF — electric blue
    private let liveAccent = Color(red: 0.994, green: 0.297, blue: 0.16)  // #FD4B28 — icon radio-arc red

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RaceActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color(red: 0.024, green: 0.043, blue: 0.09))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.attributes.flag) \(context.attributes.sessionShort)")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isLive {
                        Text("LIVE")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(liveAccent)
                    } else {
                        countdownText(to: context.state.sessionDate, size: 15)
                            .foregroundStyle(accent)
                            .frame(maxWidth: 80)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        Text(context.attributes.raceName.uppercased())
                            .font(.system(size: 13, weight: .black).width(.condensed).italic())
                            .foregroundStyle(.white)
                        Text(context.state.isLive
                             ? "\(context.attributes.sessionName.uppercased()) IS ON TRACK"
                             : "\(context.attributes.sessionName.uppercased()) · STARTING SOON")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                if context.state.isLive {
                    Circle()
                        .fill(liveAccent)
                        .frame(width: 10, height: 10)
                } else {
                    Text("🏁")
                }
            } compactTrailing: {
                if context.state.isLive {
                    Text("LIVE")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(liveAccent)
                } else {
                    countdownText(to: context.state.sessionDate, size: 12)
                        .foregroundStyle(accent)
                        .frame(maxWidth: 60)
                }
            } minimal: {
                if context.state.isLive {
                    Circle()
                        .fill(liveAccent)
                        .frame(width: 10, height: 10)
                } else {
                    Text("🏁")
                }
            }
            .keylineTint(accent)
        }
    }

    /// Ticking H:MM:SS only makes sense close to the session; further out the
    /// hour count balloons ("279:47:34") and wraps. Relative style reads
    /// naturally at any distance.
    private func countdownText(to date: Date, size: CGFloat) -> some View {
        Group {
            if date.timeIntervalSinceNow > 24 * 3600 {
                Text(date, style: .relative)
            } else {
                Text(timerInterval: Date.now...date, countsDown: true)
            }
        }
        .font(.system(size: size, weight: .black).width(.condensed).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .multilineTextAlignment(.trailing)
    }

    private func lockScreenView(_ context: ActivityViewContext<RaceActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(context.attributes.flag)
                    Text(context.attributes.raceName.uppercased())
                        .font(.system(size: 15, weight: .black).width(.condensed).italic())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(context.attributes.sessionName.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
            }

            Spacer()

            if context.state.isLive {
                HStack(spacing: 7) {
                    Circle()
                        .fill(liveAccent)
                        .frame(width: 10, height: 10)
                    Text("LIVE")
                        .font(.system(size: 24, weight: .black).width(.condensed))
                        .foregroundStyle(liveAccent)
                }
            } else {
                VStack(alignment: .trailing, spacing: 0) {
                    countdownText(to: context.state.sessionDate, size: 26)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 140, alignment: .trailing)
                    Text("TO GREEN LIGHT")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(16)
    }
}
