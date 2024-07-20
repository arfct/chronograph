import WeatherKit
import CoreLocation

class WeatherLocationManager: NSObject {
  private let locationManager = LocationManager()
  private var locationContinuation: CheckedContinuation<CLLocation, Error>?

  @MainActor
  func fetchWeather() async throws -> Weather {
    let location = try await locationManager.currentLocation
    let weatherService = WeatherService.shared
    return try await weatherService.weather(for: location)
  }

}
