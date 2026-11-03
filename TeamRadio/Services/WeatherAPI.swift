import Foundation

/// One hour of forecast at the circuit.
struct WeatherPoint {
    let temperature: Double
    let precipProbability: Int
    let code: Int

    /// WMO weather code → glyph.
    var symbol: String {
        switch code {
        case 0: "☀️"
        case 1, 2: "🌤️"
        case 3: "☁️"
        case 45, 48: "🌫️"
        case 51...57: "🌦️"
        case 61...67, 80...82: "🌧️"
        case 71...77, 85, 86: "🌨️"
        case 95...99: "⛈️"
        default: "🌥️"
        }
    }

    /// WMO weather code → a word or two.
    var label: String {
        switch code {
        case 0: "CLEAR"
        case 1, 2: "PARTLY CLOUDY"
        case 3: "OVERCAST"
        case 45, 48: "FOG"
        case 51...57: "DRIZZLE"
        case 61...67, 80...82: "RAIN"
        case 71...77, 85, 86: "SNOW"
        case 95...99: "THUNDERSTORMS"
        default: "CLOUDY"
        }
    }
}

/// Free hourly forecasts from Open-Meteo — no API key needed.
enum WeatherAPI {
    /// Hourly forecast around the circuit for the next 16 days, keyed by
    /// UTC hour start.
    static func hourlyForecast(latitude: String, longitude: String) async throws -> [Date: WeatherPoint] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: latitude),
            URLQueryItem(name: "longitude", value: longitude),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "forecast_days", value: "16"),
            URLQueryItem(name: "timezone", value: "UTC"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15

        struct Response: Decodable {
            struct Hourly: Decodable {
                let time: [String]
                let temperature_2m: [Double?]
                let precipitation_probability: [Int?]
                let weather_code: [Int?]
            }
            let hourly: Hourly
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let hourly = try JSONDecoder().decode(Response.self, from: data).hourly

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        var result: [Date: WeatherPoint] = [:]
        for (index, timeString) in hourly.time.enumerated() {
            guard let date = formatter.date(from: timeString),
                  let temp = hourly.temperature_2m[index],
                  let code = hourly.weather_code[index] else { continue }
            result[date] = WeatherPoint(
                temperature: temp,
                precipProbability: hourly.precipitation_probability[index] ?? 0,
                code: code
            )
        }
        return result
    }

    /// The forecast hour covering a session start.
    static func point(for date: Date, in forecast: [Date: WeatherPoint]) -> WeatherPoint? {
        let hourStart = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        return forecast[hourStart]
    }
}
