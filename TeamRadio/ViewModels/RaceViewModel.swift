import Foundation
import Observation

@Observable
@MainActor
final class RaceViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var phase: Phase = .loading
    /// The real upcoming round — chat, alerts and the live bar stay on it.
    var nextRace: Race?
    /// A round the user picked from the season strip to look at; nil = next race.
    var selectedRace: Race?
    var season: [Race] = []
    var standings: [DriverStanding] = []
    var trackMap: TrackMap?
    /// Hourly forecast at the displayed race's circuit, keyed by UTC hour
    /// (Open-Meteo only reaches ~16 days ahead, so far rounds have none).
    var weather: [Date: WeatherPoint] = [:]

    /// What the countdown tab shows: the browsed round, else the next one.
    var displayRace: Race? { selectedRace ?? nextRace }
    var isBrowsing: Bool { selectedRace != nil && selectedRace?.id != nextRace?.id }

    private var hasLoadedOnce = false
    private var mapCache: [String: TrackMap] = [:]
    private var extrasTask: Task<Void, Never>?

    func load() async {
        if !hasLoadedOnce { phase = .loading }
        do {
            async let next = F1API.nextRace()
            async let calendar = F1API.season()
            async let top = F1API.driverStandings(limit: 5)

            let (race, races, drivers) = try await (next, calendar, top)
            nextRace = race
            season = races
            standings = drivers
            phase = .loaded
            hasLoadedOnce = true

            // A browsed round that no longer exists in the calendar falls back.
            if let selectedRace, !races.contains(where: { $0.id == selectedRace.id }) {
                self.selectedRace = nil
            }
            await loadExtras(for: displayRace)
        } catch {
            // Keep stale data on screen if a refresh fails; only surface the
            // error state when we have nothing to show at all.
            if !hasLoadedOnce {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// Browse another round (nil returns to the next race).
    func select(_ race: Race?) async {
        selectedRace = race?.id == nextRace?.id ? nil : race
        await loadExtras(for: displayRace)
    }

    /// Map and weather are bonuses — fetched after the essentials and
    /// allowed to fail silently. Maps are cached per circuit.
    private func loadExtras(for race: Race?) async {
        extrasTask?.cancel()
        guard let race else {
            trackMap = nil
            weather = [:]
            return
        }
        trackMap = mapCache[race.circuit.circuitId]
        weather = [:]
        let task = Task { [weak self] in
            async let map: TrackMap? = self?.mapCache[race.circuit.circuitId] != nil ? nil
                : try? await TrackAPI.trackMap(circuitId: race.circuit.circuitId, season: race.season)
            async let forecast: [Date: WeatherPoint]? = {
                guard let lat = race.circuit.location.lat,
                      let long = race.circuit.location.long else { return nil }
                return try? await WeatherAPI.hourlyForecast(latitude: lat, longitude: long)
            }()
            let (loadedMap, loadedWeather) = await (map, forecast)
            guard !Task.isCancelled, let self, self.displayRace?.id == race.id else { return }
            if let loadedMap {
                self.mapCache[race.circuit.circuitId] = loadedMap
                self.trackMap = loadedMap
            }
            self.weather = loadedWeather ?? [:]
        }
        extrasTask = task
        await task.value
    }
}
