import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    
    //MARK: Object to Access Location Services
    private let locationManager = CLLocationManager()
    
    //MARK: Set up the Location Manager Delegate
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    //MARK: Request Authorization to access the User Location
    func checkAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            return
        }
    }
    
    //MARK: Continuation Object for the User Location
    private var continuation: CheckedContinuation<CLLocation, Error>?
    
    //MARK: Async Request the Current Location
    var currentLocation: CLLocation {
        get async throws {
            return try await withCheckedThrowingContinuation { continuation in
                // 1. Set up the continuation object
                self.continuation = continuation
                // 2. Triggers the update of the current location
                locationManager.requestLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 4. If there is a location available
        if let lastLocation = locations.last {
            // 5. Resumes the continuation object with the user location as result
            continuation?.resume(returning: lastLocation)
            // Resets the continuation object
            continuation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 6. If not possible to retrieve a location, resumes with an error
        continuation?.resume(throwing: error)
        // Resets the continuation object
        continuation = nil
    }
    
}
