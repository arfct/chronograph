import WeatherKit
import CoreLocation

class WeatherLocationManager: NSObject {
  private let locationManager = LocationManager()
  private var locationContinuation: CheckedContinuation<CLLocation, Error>?
  private var cachedWeather: Weather?

  @MainActor
  func fetchWeather() async throws -> Weather {

    if let data = UserDefaults.standard.data(forKey: "cachedWeather") {
      cachedWeather = try JSONDecoder().decode(Weather.self, from: data)
    }
    
    if let weather = cachedWeather, let date = cachedWeather?.currentWeather.date, Date().timeIntervalSince(date) <= 300 {
      print("Returning cached weather \(Date().timeIntervalSince(date) )")
      return weather
    }

    let location = try await locationManager.currentLocation
    let weatherService = WeatherService.shared
    print("Fetching Weather for \(location.coordinate.latitude), \(location.coordinate.longitude)")

    let weather = try await weatherService.weather(for: location)

    // Cache the weather and update the last cached time
    cachedWeather = weather
    UserDefaults.standard.set(try? JSONEncoder().encode(weather), forKey: "cachedWeather")

    return weather
  }
}
