import SwiftUI

/// About & legal: non-affiliation disclaimer, data accuracy notice, and the
/// source attributions required by the data licenses.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 0) {
                                Text("TEAM").foregroundStyle(.white)
                                Text("RADIO").foregroundStyle(Theme.accent)
                            }
                            .font(.f1(30).italic())
                            Text("VERSION \(version)")
                                .font(.f1(11, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(Theme.faintText)
                        }

                        section("UNOFFICIAL APP") {
                            Text("Team Radio is an independent fan project. It is not affiliated with, endorsed by, or associated in any way with Formula 1, Formula One Group, the FIA, or any team, driver, or circuit. F1, FORMULA 1, GRAND PRIX and related marks are trademarks of their respective owners and appear here only as factual references to the sport.")
                        }

                        section("DATA & ACCURACY") {
                            Text("All information in this app — schedules, session times, results, standings, and circuit data — comes from public, community-maintained sources and is provided “as is”, with no warranty of accuracy, completeness, or timeliness.\n\nSession times can change at short notice. Always confirm with official sources before making plans. The developer accepts no responsibility or liability for errors in the data or for any decisions made based on information shown in this app.")
                        }

                        section("DATA SOURCES & ATTRIBUTION") {
                            VStack(alignment: .leading, spacing: 10) {
                                attribution(
                                    name: "Jolpica F1 API",
                                    detail: "Race schedule, results, and standings. Data licensed under CC BY-NC-SA 4.0.",
                                    url: "https://github.com/jolpica/jolpica-f1"
                                )
                                attribution(
                                    name: "MultiViewer",
                                    detail: "Circuit map geometry and track data.",
                                    url: "https://multiviewer.app"
                                )
                                attribution(
                                    name: "OpenStreetMap",
                                    detail: "Circuit geometry for some tracks. Map data © OpenStreetMap contributors, licensed under ODbL.",
                                    url: "https://www.openstreetmap.org/copyright"
                                )
                                attribution(
                                    name: "Formula1.com · BBC Sport · Motorsport.com",
                                    detail: "News headlines via public RSS feeds. All articles remain the property of their publishers; stories open at the original source.",
                                    url: nil
                                )
                            }
                        }

                        section("APP") {
                            Text("Team Radio is open source under the MIT License. The app collects no personal data, uses no trackers, and requires no account.")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Theme.glassStroke, lineWidth: 1)
                        )
                )
        }
    }

    private func attribution(name: String, detail: String, url: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let url, let link = URL(string: url) {
                Link(destination: link) {
                    HStack(spacing: 4) {
                        Text(name).font(.system(size: 14, weight: .bold))
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.accent)
                }
            } else {
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.dimText)
        }
    }
}
