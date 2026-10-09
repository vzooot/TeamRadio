import Foundation

/// Circuit guide: one checked line per corner, built from the real track
/// geometry (scripts/guide/make_guide.py) and served by the Worker, so a wrong
/// line is fixed without an app update.
struct CircuitGuide: Decodable, Equatable {
    struct Corner: Decodable, Equatable, Identifiable {
        let number: Int
        let name: String
        let text: String
        let moment: String
        var id: Int { number }
    }

    let circuitId: String
    let corners: [Corner]

    func corner(_ number: Int?) -> Corner? {
        corners.first { $0.number == number }
    }
}

enum GuideService {
    private static var cache: [String: CircuitGuide] = [:]

    static func guide(circuitId: String, corners: Int) async -> CircuitGuide? {
        if let cached = cache[circuitId] { return cached }
        var components = URLComponents(string: "https://teamradio-push.eam-adio.workers.dev/guide")!
        components.queryItems = [URLQueryItem(name: "circuit", value: circuitId),
                                 URLQueryItem(name: "corners", value: String(corners))]
        guard let (data, response) = try? await URLSession.shared.data(from: components.url!),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let guide = try? JSONDecoder().decode(CircuitGuide.self, from: data) else { return nil }
        cache[circuitId] = guide
        return guide
    }
}
