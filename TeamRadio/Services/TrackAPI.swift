import Foundation

/// Client for the MultiViewer circuits API, which serves real track centerline
/// coordinates and corner data. https://api.multiviewer.app
enum TrackAPI {
    /// Ergast circuitId → MultiViewer circuitKey.
    /// Discovered by probing the /circuits index; new circuits (Madring, Sepang)
    /// have no map data yet and are intentionally absent — they ship bundled
    /// OSM geometry instead (Resources/madring.json, sepang.json).
    static let circuitKeys: [String: Int] = [
        "albert_park": 10,
        "shanghai": 49,
        "suzuka": 46,
        "miami": 151,
        "villeneuve": 23,
        "monaco": 22,
        "catalunya": 15,
        "red_bull_ring": 19,
        "silverstone": 2,
        "spa": 7,
        "hungaroring": 4,
        "zandvoort": 55,
        "monza": 39,
        "baku": 144,
        "marina_bay": 61,
        "americas": 9,
        "rodriguez": 65,
        "interlagos": 14,
        "vegas": 152,
        "losail": 150,
        "yas_marina": 70,
        // Circuits not on the current calendar, kept for robustness.
        "bahrain": 63,
        "jeddah": 149,
        "imola": 6,
        "portimao": 147,
        "istanbul": 59,
        "sochi": 79,
        "nurburgring": 72,
        "mugello": 146,
        "hockenheimring": 34,
        "ricard": 28,
    ]

    /// Fetches the track map for an Ergast circuitId, falling back to a
    /// bundled OpenStreetMap-derived centerline for circuits MultiViewer
    /// doesn't cover (Madring, Sepang).
    static func trackMap(circuitId: String, season: String) async throws -> TrackMap? {
        if let key = circuitKeys[circuitId] {
            let url = URL(string: "https://api.multiviewer.app/api/v1/circuits/\(key)/\(season)")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               let map = try? JSONDecoder().decode(TrackMap.self, from: data) {
                return map
            }
        }
        return bundledMap(circuitId: circuitId)
    }

    /// Ships-with-the-app geometry (Resources/<circuitId>.json), traced from
    /// OpenStreetMap. © OpenStreetMap contributors.
    private static func bundledMap(circuitId: String) -> TrackMap? {
        guard let url = Bundle.main.url(forResource: circuitId, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TrackMap.self, from: data)
    }
}
