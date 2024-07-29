import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
  
  override init() {
    super.init()
    locationManager.delegate = self
  }
  
  var isAuthorized: Bool  {
#if os(macOS)
    return locationManager.authorizationStatus == .authorizedAlways || locationManager.authorizationStatus == .notDetermined
#else
    return locationManager.authorizationStatus == .authorizedWhenInUse
#endif
  }
  
  func checkAuthorization() {
    print(locationManager.authorizationStatus.rawValue)
    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .denied:
      openAppSettings()
    default:
      return
    }
  }
  
  private var continuation: CheckedContinuation<CLLocation, Error>?
  
  var currentLocation: CLLocation {
    get async throws {
      return try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        locationManager.requestLocation()
      }
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastLocation = locations.last {
      continuation?.resume(returning: lastLocation)
      continuation = nil
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
  
}
