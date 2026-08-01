import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
  let locationManager = CLLocationManager()

  // Multiple timelines can await a location at once (the widget extension
  // shares one engine). Each waiter is keyed so it resumes exactly once:
  // either by a delegate callback or by its own timeout.
  private let lock = NSLock()
  private var waiters: [UUID: CheckedContinuation<CLLocation, Error>] = [:]
  private static let timeout: TimeInterval = 10

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

    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .denied:
      openAppSettings()
    default:
      return
    }
  }

  var currentLocation: CLLocation {
    get async throws {
      let id = UUID()
      return try await withCheckedThrowingContinuation { continuation in
        lock.lock()
        waiters[id] = continuation
        lock.unlock()

        locationManager.requestLocation()

        Task { [weak self] in
          try? await Task.sleep(nanoseconds: UInt64(Self.timeout * 1_000_000_000))
          self?.take(id)?.resume(throwing: NSError(
            domain: "LocationManager", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for location"]))
        }
      }
    }
  }

  private func take(_ id: UUID) -> CheckedContinuation<CLLocation, Error>? {
    lock.lock()
    defer { lock.unlock() }
    return waiters.removeValue(forKey: id)
  }

  private func takeAll() -> [CheckedContinuation<CLLocation, Error>] {
    lock.lock()
    defer { lock.unlock() }
    let all = Array(waiters.values)
    waiters.removeAll()
    return all
  }

  deinit {
    takeAll().forEach { $0.resume(throwing: CLError(.locationUnknown)) }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let lastLocation = locations.last {
      takeAll().forEach { $0.resume(returning: lastLocation) }
    } else {
      // requestLocation() delivers exactly one callback; an empty array means
      // the request is over with no fix. Fail now rather than stalling to the timeout.
      takeAll().forEach { $0.resume(throwing: CLError(.locationUnknown)) }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    takeAll().forEach { $0.resume(throwing: error) }
  }

}
