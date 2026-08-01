import WeatherKit
import CoreLocation

/// Fetches WeatherKit forecasts for either the device location or a fixed
/// zip/postal code, caching aggressively so widget timeline reloads never
/// stall on CoreLocation or the geocoder.
class WeatherLocationManager: NSObject {
  private struct CachedWeather: Codable {
    let weather: Weather
    let locationName: String?
    let fetchDate: Date
  }

  private struct GeocodedPlace: Codable {
    let latitude: Double
    let longitude: Double
    let name: String?

    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
  }

  private static let cacheLifetime: TimeInterval = 5 * 60
  private static let maxCachedLocations = 4

  private let locationManager = LocationManager()
  private let defaults = UserDefaults(suiteName: Keys.suiteName) ?? .standard

  /// - Parameter zipCode: empty means current location.
  @MainActor
  func fetchWeather(zipCode: String = "") async throws -> (Weather, String?) {
    let cacheKey = zipCode.isEmpty ? "current" : zipCode

    let cached = loadCache(key: cacheKey)
    if let cached, Date().timeIntervalSince(cached.fetchDate) <= Self.cacheLifetime {
      return (cached.weather, cached.locationName)
    }

    do {
      let (location, locationName) = try await resolveLocation(zipCode: zipCode)
      let weather = try await WeatherService.shared.weather(for: location)

      saveCache(CachedWeather(weather: weather, locationName: locationName, fetchDate: Date()),
                key: cacheKey)

      return (weather, locationName)
    } catch {
      // A stale forecast beats an empty widget.
      if let cached {
        return (cached.weather, cached.locationName)
      }
      throw error
    }
  }

  // MARK: Forecast cache

  // Forecast JSON runs ~500 KB, so it lives in files in the shared
  // container (UserDefaults is unsuitable for values that size).
  private var cacheDirectory: URL? {
    guard let base = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: Keys.suiteName) else { return nil }
    let directory = base.appendingPathComponent("WeatherCache", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func cacheFile(key: String) -> URL? {
    let safeKey = key.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "-")
    return cacheDirectory?.appendingPathComponent("\(safeKey).json")
  }

  private func loadCache(key: String) -> CachedWeather? {
    guard let file = cacheFile(key: key),
          let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(CachedWeather.self, from: data)
  }

  private func saveCache(_ entry: CachedWeather, key: String) {
    guard let file = cacheFile(key: key),
          let data = try? JSONEncoder().encode(entry) else { return }
    try? data.write(to: file)
    evictOldCaches(keeping: file)
    purgeLegacyDefaultsCache()
  }

  private func evictOldCaches(keeping current: URL) {
    guard let directory = cacheDirectory,
          let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }

    let byRecency = files.sorted { a, b in
      let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return dateA > dateB
    }

    for file in byRecency.dropFirst(Self.maxCachedLocations) where file != current {
      try? FileManager.default.removeItem(at: file)
    }
  }

  /// Earlier builds stored forecasts directly in UserDefaults.
  private func purgeLegacyDefaultsCache() {
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Keys.cachedWeatherPrefix) {
      defaults.removeObject(forKey: key)
    }
    UserDefaults.standard.removeObject(forKey: "cachedWeather")
  }

  // MARK: Location resolution

  private func resolveLocation(zipCode: String) async throws -> (CLLocation, String?) {
    if zipCode.isEmpty {
      return try await currentLocation()
    }
    return try await geocodedLocation(zipCode: zipCode)
  }

  private func currentLocation() async throws -> (CLLocation, String?) {
    let location: CLLocation
    do {
      location = try await locationManager.currentLocation
      let place = GeocodedPlace(latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude,
                                name: nil)
      defaults.set(try? JSONEncoder().encode(place), forKey: Keys.lastKnownLocation)
    } catch {
      // No fix right now (timeout, airplane mode); reuse the last known
      // coordinate rather than failing the whole fetch.
      guard let data = defaults.data(forKey: Keys.lastKnownLocation),
            let place = try? JSONDecoder().decode(GeocodedPlace.self, from: data) else {
        throw error
      }
      location = place.location
    }

    // The name is decoration; never fail the fetch over reverse geocoding.
    let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
    return (location, placemarks?.first?.locality)
  }

  private func geocodedLocation(zipCode: String) async throws -> (CLLocation, String?) {
    let cacheKey = Keys.geocodedZipPrefix + zipCode
    if let data = defaults.data(forKey: cacheKey),
       let place = try? JSONDecoder().decode(GeocodedPlace.self, from: data) {
      return (place.location, place.name)
    }

    let placemarks = try await CLGeocoder().geocodeAddressString(zipCode)
    guard let placemark = placemarks.first, let location = placemark.location else {
      throw CLError(.geocodeFoundNoResult)
    }

    let name = placemark.locality ?? placemark.name ?? zipCode
    let place = GeocodedPlace(latitude: location.coordinate.latitude,
                              longitude: location.coordinate.longitude,
                              name: name)
    defaults.set(try? JSONEncoder().encode(place), forKey: cacheKey)
    return (location, name)
  }
}
