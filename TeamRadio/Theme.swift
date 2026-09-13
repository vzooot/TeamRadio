import SwiftUI

/// Visual language of the app: dark cockpit palette drawn from the app icon —
/// neon-cyan comm ring, coral radio arc — with condensed italic type.
enum Theme {
    /// Primary accent: electric blue, matching the icon's cool glow.
    static let accent = Color(red: 0.18, green: 0.70, blue: 1.0)           // #2EB2FF
    /// Red-orange of the radio-wave arc: live sessions, alerts, errors.
    static let live = Color(red: 0.994, green: 0.297, blue: 0.16)          // #FD4B28
    /// Text/icons placed on an accent-filled surface.
    static let onAccent = Color(red: 0.01, green: 0.043, blue: 0.09)       // #030B17
    static let background = Color(red: 0.024, green: 0.043, blue: 0.09)    // #060B17
    static let card = Color(red: 0.055, green: 0.09, blue: 0.155)          // #0E1728
    static let cardStroke = Color(red: 0.45, green: 0.72, blue: 1.0).opacity(0.12)
    static let dimText = Color.white.opacity(0.55)
    static let faintText = Color.white.opacity(0.35)

    /// Team colors keyed by Ergast constructorId.
    static let teamColors: [String: Color] = [
        "red_bull": Color(red: 0.14, green: 0.12, blue: 0.60),
        "ferrari": Color(red: 0.91, green: 0.05, blue: 0.05),
        "mercedes": Color(red: 0.0, green: 0.82, blue: 0.75),
        "mclaren": Color(red: 1.0, green: 0.53, blue: 0.0),
        "aston_martin": Color(red: 0.0, green: 0.44, blue: 0.37),
        "alpine": Color(red: 0.0, green: 0.57, blue: 1.0),
        "williams": Color(red: 0.0, green: 0.35, blue: 0.75),
        "rb": Color(red: 0.42, green: 0.57, blue: 1.0),
        "racing_bulls": Color(red: 0.42, green: 0.57, blue: 1.0),
        "sauber": Color(red: 0.0, green: 0.89, blue: 0.3),
        "audi": Color(red: 0.6, green: 0.9, blue: 0.2),
        "haas": Color(red: 0.7, green: 0.7, blue: 0.7),
        "cadillac": Color(red: 0.85, green: 0.75, blue: 0.4),
    ]

    static func teamColor(_ constructorId: String?) -> Color {
        guard let id = constructorId else { return .gray }
        return teamColors[id] ?? .gray
    }
}

extension Font {
    /// The Team Radio look: heavy weight, rounded — smooth and bold.
    /// Apply .italic() at the call site when wanted.
    static func f1(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func f1Digits(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded).monospacedDigit()
    }
}

/// Country name (as Ergast reports it) → flag emoji.
enum Flags {
    private static let map: [String: String] = [
        "Australia": "🇦🇺", "China": "🇨🇳", "Japan": "🇯🇵", "Bahrain": "🇧🇭",
        "Saudi Arabia": "🇸🇦", "USA": "🇺🇸", "United States": "🇺🇸", "Italy": "🇮🇹",
        "Monaco": "🇲🇨", "Canada": "🇨🇦", "Spain": "🇪🇸", "Austria": "🇦🇹",
        "UK": "🇬🇧", "United Kingdom": "🇬🇧", "Great Britain": "🇬🇧",
        "Hungary": "🇭🇺", "Belgium": "🇧🇪", "Netherlands": "🇳🇱",
        "Azerbaijan": "🇦🇿", "Singapore": "🇸🇬", "Mexico": "🇲🇽",
        "Brazil": "🇧🇷", "Qatar": "🇶🇦", "UAE": "🇦🇪", "United Arab Emirates": "🇦🇪",
        "France": "🇫🇷", "Germany": "🇩🇪", "Portugal": "🇵🇹", "Vietnam": "🇻🇳",
        "South Africa": "🇿🇦", "Korea": "🇰🇷", "India": "🇮🇳", "Turkey": "🇹🇷",
        "Russia": "🇷🇺", "Argentina": "🇦🇷", "Malaysia": "🇲🇾", "Thailand": "🇹🇭",
        "Rwanda": "🇷🇼",
    ]

    static func emoji(for country: String?) -> String {
        guard let country else { return "🏁" }
        return map[country] ?? "🏁"
    }
}
